#!/bin/bash

# Script and working directory
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
WD=$(dirname "$SCRIPT_DIR")

# Default variable values
backup=true
default_port="5432"
skip_db_steps=false
dump_to_use=""
dump_folder="/home/ubuntu/dumps"
properties_path="/home/ubuntu/.intermine/mdrmine.properties"
verbose=false

local_prod_db=""
local_prod_user=""
local_prod_pass=""
local_prod_host=""
local_prod_port=""
remote_prod_db=""
remote_prod_user=""
remote_prod_pass=""
remote_prod_host=""
remote_prod_port=""

usage() {
    echo "Deploy"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -d=[dump_path], --dump-to-use=[dump_path]                    Path of dump to use, dumps local MDRMine DB instead if empty"
    echo " -n, --no-backup                                              Don't dump remote DB"
    echo " -p=[properties_path], --properties-path=[properties_path]    Set properties file path, default: $properties_path"
    echo " -s, --skip-db-steps                                          Skip all pg_dump/pg_restore steps, only perform the remote postprocess and webapp redeployment"
    echo " -v, --verbose                                                Enable verbose mode (TODO, outputs commands)"
}

# Reads the value of a property from a properties file.
#
# $1 - Key name, matched at beginning of line.
get_prop() {
    grep "^${1}" $properties_path|cut -d'=' -f2
}

load_db_properties() {
    # Local DB
    local_prod_host=$(get_prop "db.production.datasource.serverName")
    local_prod_db=$(get_prop "db.production.datasource.databaseName")
    local_prod_user=$(get_prop "db.production.datasource.user")
    local_prod_pass=$(get_prop "db.production.datasource.password")
    local_prod_port=$(get_prop "db.production.datasource.port")

    if [[ $local_prod_host = "" ]]; then
        echo "Local hostname is empty, please add 'db.production.datasource.serverName' property to properties file"
        exit 1
    fi

    if [[ $local_prod_db = "" ]]; then
        echo "Local database name is empty, please add 'db.production.datasource.databaseName' property to properties file"
        exit 1
    fi

    if [[ $local_prod_user = "" ]]; then
        echo "Local database username is empty, please add 'db.production.datasource.user' property to properties file"
        exit 1
    fi

    if [[ $local_prod_port = "" ]]; then
        local_prod_port=$default_port;
    fi
    
    # Remote DB
    remote_prod_host=$(get_prop "remote.production.datasource.serverName")
    remote_prod_db=$(get_prop "remote.production.datasource.databaseName")
    remote_prod_user=$(get_prop "remote.production.datasource.user")
    remote_prod_pass=$(get_prop "remote.production.datasource.password")
    remote_prod_port=$(get_prop "remote.production.datasource.port")
    
    if [[ $remote_prod_host = "" ]]; then
        echo "Remote hostname is empty, please add 'remote.production.datasource.serverName' property to properties file"
        exit 1
    fi

    if [[ $remote_prod_db = "" ]]; then
        echo "Remote database name is empty, please add 'remote.production.datasource.databaseName' property to properties file"
        exit 1
    fi

    if [[ $remote_prod_user = "" ]]; then
        echo "Remote database username is empty, please add 'remote.production.datasource.user' property to properties file"
        exit 1
    fi

    if [[ $remote_prod_host = "" ]]; then
        remote_prod_port=$default_port;
    fi

    # Remote machine user for SSH
    # TODO: allow empty? modify ssh command if yes
    remote_user=$(get_prop "remote.user")
}

deploy_remote() {
    if [[ "$verbose" = true ]]; then
        # TODO: improve verbose
        set -x
    fi

    load_db_properties

    mkdir -p $dump_folder

    if [[ "$skip_db_steps" = false ]]; then
        if [[ "$dump_to_use" = "" ]]; then
            echo "Dumping local DB to $dump_folder"
            dump_to_use="$dump_folder/$(date +"%Y%m%d_%H%M%S")_local_dump.sql"
            pg_dump -h "$local_prod_host" -p "$local_prod_port" -U "$local_prod_user" -d "$local_prod_db" -F c > $dump_to_use
        fi

        if [[ "$backup" = true ]]; then
            echo "Backing up remote DB to $dump_folder"
            pg_dump -h "$remote_prod_host" -p "$remote_prod_port" -U "$remote_prod_user" -d "$remote_prod_db" -F c >  $dump_folder/$(date +"%Y%m%d_%H%M%S")_remote_dump.sql
        fi
        
        echo "Rebuilding DB on remote to align with potential model changes"
        # TODO: Many things should be args here
        ssh $remote_user@$remote_prod_host -o StrictHostKeyChecking=no <<EOF
            cd ./code/mdrmine;
            docker build -f Dockerfiles/main/Dockerfile --target mdrmine_builddb -t mdrmine_builddb .;
            docker run --mount type=bind,src=/home/ubuntu/.intermine,dst=/root/.intermine_base --network=mdrmine_default mdrmine_builddb;
EOF
        
        echo "Transferring local build to remote machine"
        if [[ -f $dump_to_use ]]; then
            pg_restore --clean -h "$remote_prod_host" -p "$remote_prod_port" -U "$remote_prod_user" -d "$remote_prod_db" $dump_to_use
        else
            echo "Couldn't find dump file '$dump_to_use' to load into remote DB"
        fi
    fi
    
    search_dump="$(date +"%Y%m%d_%H%M%S")_search_dump"
    autocomplete_dump="$(date +"%Y%m%d_%H%M%S")_autocomplete_dump"

    # TODO: port to settings?
    # TODO: query frequency to settings
    # Dumping mdrmine-search core and waiting for the dump to be completed before continuing
    curl "http://$local_prod_host:8983/solr/mdrmine-search/replication?command=backup&location=/solr_backups&name=$search_dump"
    until curl "http://$local_prod_host:8983/solr/mdrmine-search/replication?command=details" | grep "\"status\":\"OK\""; do
        sleep 1;
    done

    # Dumping mdrmine-autocomplete core and waiting for the dump to be completed before continuing
    curl "http://$local_prod_host:8983/solr/mdrmine-autocomplete/replication?command=backup&location=/solr_backups&name=$autocomplete_dump"
    until curl "http://$local_prod_host:8983/solr/mdrmine-autocomplete/replication?command=details" | grep "\"status\":\"OK\""; do
        sleep 1;
    done
    # TODO: test rsync
    # https://stackoverflow.com/a/22908437
    rsync -a $dump_folder/solr/$search_dump $remote_user@$remote_prod_host:./dumps/solr/
    rsync -a $dump_folder/solr/$autocomplete_dump $remote_user@$remote_prod_host:./dumps/solr/
    # curl "http://$remote_prod_host:8983/solr/mdrmine-search/replication?command=restore&location=/solr_backups&name=$search_dump"
    # curl "http://$remote_prod_host:8983/solr/mdrmine-autocomplete/replication?command=restore&location=/solr_backups&name=$autocomplete_dump"
    # TODO: Many things should be args here
#     ssh $remote_user@$remote_prod_host -o StrictHostKeyChecking=no <<EOF
#         cd ./code/mdrmine;
#         docker run --mount type=bind,src=/home/ubuntu/.intermine,dst=/root/.intermine_base --volume mdrmine_webapps:/webapps --network=mdrmine_default mdrmine_deploy;
# EOF
}


# Parsing command-line arguments
for i in "$@"; do
  case $i in
    -d=*|--dump-to-use=*)
        dump_to_use="${i#*=}"
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    -n | --no-backup)
        backup=false
        shift
        ;;
    -p=*|--properties-path=*)
        properties_path="${i#*=}"
        shift
        ;;
    -s | --skip-db-steps)
        skip_db_steps=true
        shift
        ;;
    -v | --verbose)
        verbose=true
        shift
        ;;
    -*|--*)
        echo "Error: invalid option '$i'" >&2
        usage
        exit 1
        ;;
  esac
done

deploy_remote