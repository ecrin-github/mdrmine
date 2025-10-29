#!/bin/bash

# Script and working directory
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
WD=$(dirname "$SCRIPT_DIR")

# Default variable values
backup=true
default_port="5432"
default_solr_port="8983"
dump_to_use=""
dump_folder="/home/ubuntu/dumps"
properties_path="/home/ubuntu/.intermine/mdrmine.properties"
remote_mdrmine_path="/home/ubuntu/code/mdrmine" # TODO: add cmd-line arg to modify the value
skip_db_steps=false
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
    echo "Deploy a local MDRMine build to a remote instance (DB, Solr, Webapp redeployment)"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -d=[dump_folder], --dump-folder=[dump_folder]                Folder with dumps/where to dump, default: $dump_folder"
    echo " -f=[dump_path], --dump-file-to-use=[dump_path]               Path of dump to use, dumps local MDRMine DB instead if empty"
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
    local_solr_port=$(get_prop "local.solr.port")

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

    if [[ $local_solr_port = "" ]]; then
        local_solr_port=$default_solr_port;
    fi
    
    # Remote DB
    remote_prod_host=$(get_prop "remote.production.datasource.serverName")
    remote_prod_db=$(get_prop "remote.production.datasource.databaseName")
    remote_prod_user=$(get_prop "remote.production.datasource.user")
    remote_prod_pass=$(get_prop "remote.production.datasource.password")
    remote_prod_port=$(get_prop "remote.production.datasource.port")
    remote_solr_port=$(get_prop "remote.solr.port")
    
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

    if [[ $remote_solr_port = "" ]]; then
        remote_solr_port=$default_solr_port;
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
            echo "Dumping remote DB to $dump_folder"
            pg_dump -h "$remote_prod_host" -p "$remote_prod_port" -U "$remote_prod_user" -d "$remote_prod_db" -F c >  $dump_folder/$(date +"%Y%m%d_%H%M%S")_remote_dump.sql
        fi
        
        echo "Rebuilding DB on remote to align with potential model changes"
        # TODO: Many things should be args here
        ssh $remote_user@$remote_prod_host -o StrictHostKeyChecking=no <<EOF
            cd $remote_mdrmine_path;
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
    
    autocomplete_dump_local="$(date +"%Y%m%d_%H%M%S")_autocomplete_dump"
    search_dump_local="$(date +"%Y%m%d_%H%M%S")_search_dump"

    echo "Dumping mdrmine-autocomplete core"

    curl "http://$local_prod_host:$local_solr_port/solr/mdrmine-autocomplete/replication?command=backup&location=/solr_backups&name=$autocomplete_dump_local"
    until curl "http://$local_prod_host:$local_solr_port/solr/mdrmine-autocomplete/replication?command=details" | grep -q "\"status\":\"success\""; do  # Waiting for the dump
        sleep 1;
    done

    echo "Dumping mdrmine-search core"
    curl "http://$local_prod_host:$local_solr_port/solr/mdrmine-search/replication?command=backup&location=/solr_backups&name=$search_dump_local"
    until curl "http://$local_prod_host:$local_solr_port/solr/mdrmine-search/replication?command=details" | grep -q "\"status\":\"success\""; do  # Waiting for the dump
        sleep 1;
    done

    echo "Waiting a few more seconds for solr to finish"
    # For some reason the details queries return success for backups even before all the files are actually written to disk
    # so we wait a few seconds for it to finish (might be Docker bind mount delay?)
    sleep 4
    echo "Transfering the dumps to remote host"
    # Hacky
    sudo rsync --rsync-path="sudo rsync" -a $dump_folder/solr/snapshot.$search_dump_local $remote_user@$remote_prod_host:./dumps/solr/
    sudo rsync --rsync-path="sudo rsync" -a $dump_folder/solr/snapshot.$autocomplete_dump_local $remote_user@$remote_prod_host:./dumps/solr/

    autocomplete_dump_remote="$(date +"%Y%m%d_%H%M%S")_autocomplete_dump_backup"
    search_dump_remote="$(date +"%Y%m%d_%H%M%S")_search_dump_backup"

    echo "Dumping (backup) remote mdrmine-autocomplete core"
    curl "http://$remote_prod_host:$remote_solr_port/solr/mdrmine-autocomplete/replication?command=backup&location=/solr_backups&name=$autocomplete_dump_remote"
    until curl "http://$remote_prod_host:$remote_solr_port/solr/mdrmine-autocomplete/replication?command=details" | grep "\"status\":\"success\""; do  # Waiting for the dump
        sleep 1;
    done

    echo "Dumping (backup) remote mdrmine-search core"
    curl "http://$remote_prod_host:$remote_solr_port/solr/mdrmine-search/replication?command=backup&location=/solr_backups&name=$search_dump_remote"
    until curl "http://$remote_prod_host:$remote_solr_port/solr/mdrmine-search/replication?command=details" | grep "\"status\":\"success\""; do  # Waiting for the dump
        sleep 1;
    done

    echo "Restoring local mdrmine-autocomplete core on remote instance"
    curl "http://$remote_prod_host:$remote_solr_port/solr/mdrmine-autocomplete/replication?command=restore&location=/solr_backups&name=$autocomplete_dump_local"
    until curl "http://$remote_prod_host:$remote_solr_port/solr/mdrmine-search/replication?command=details" | grep "\"status\":\"success\""; do
        sleep 1;
    done

    echo "Restoring local mdrmine-search core on remote instance"
    curl "http://$remote_prod_host:$remote_solr_port/solr/mdrmine-search/replication?command=restore&location=/solr_backups&name=$search_dump_local"
    until curl "http://$remote_prod_host:$remote_solr_port/solr/mdrmine-search/replication?command=details" | grep "\"status\":\"success\""; do
        sleep 1;
    done

    # TODO: Many things should be args here
    ssh $remote_user@$remote_prod_host -o StrictHostKeyChecking=no <<EOF
        cd $remote_mdrmine_path;
        docker build -f Dockerfiles/main/Dockerfile --target mdrmine_webapp -t mdrmine_webapp .;
        docker run --mount type=bind,src=/home/ubuntu/.intermine,dst=/root/.intermine_base --volume mdrmine_webapps:/webapps --network=mdrmine_default mdrmine_webapp;
EOF
}


# Parsing command-line arguments
for i in "$@"; do
  case $i in
    -d=*|--dump-folder=*)
        dump_folder="${i#*=}"
        shift
        ;;
    -f=*|--dump-file-to-use=*)
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