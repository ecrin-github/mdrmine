#!/bin/bash

# Default variable values
deploy_remote=false
docker=false
first_build=false
hostname="localhost"
properties_path="/root/.intermine/mdrmine.properties"
skip_install=false
skip_sources=false
sources_path="/home/ubuntu/code/mdrmine-bio-sources"
sources=""
verbose=false
default_port="5432"

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
    echo "Build and deploy MDRMine."
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -c=[properties_path], --properties-path=[properties_path]    Set properties file path, default: $properties_path"
    echo " -d, --docker                                                 Instead of ./gradlew cargoDeployRemote, uses a shared Docker volume to deploy webapp .war file"
    echo " -f, --first-build                                            Replaces ./gradlew cargoRedeployRemote by ./gradlew cargoDeployRemote"
    echo " -h, --help                                                   Show this text"
    echo " -n=[hostname], --hostname=[hostname]                         Servername properties to modify mdrmine.properties file if not localhost, default: $sources_path"
    echo " -p=[sources_path], --path=[sources_path]                     Set sources repo path, default: $sources_path"
    echo " -r, --deploy-remote                                          Build on this machine and deploy to a remote MDRMine and PSQL instance"
    echo " -s=[list of comma separated sources], --sources=[sources]    Set list of sources to integrate, default behaviour includes all in sources folder"
    echo " -v, --verbose                                                Enable verbose mode (outputs commands)"
    echo " -x, --skip-install                                           Skip ./gradlew install in bio-sources repository"
    echo " -z, --skip-sources                                           Skip integrating any source"
}

# Reads the value of a property from a properties file.
#
# $1 - Key name, matched at beginning of line.
get_prop() {
    grep "^${1}" $properties_path|cut -d'=' -f2
}

load_properties() {
    # Local DB
    local_prod_host=$(get_prop "db.production.datasource.serverName")
    local_prod_db=$(get_prop "db.production.datasource.databaseName")
    local_prod_user=$(get_prop "db.production.datasource.user")
    local_prod_pass=$(get_prop "db.production.datasource.password")
    local_prod_port=$(get_prop "db.production.datasource.port")

    if [[ $local_prod_port = "" ]]; then
        local_prod_port=$default_port;
    fi
    
    # TODO: test if not having these properties stops the script and check deploy_remote accordingly
    # Remote DB
    remote_prod_host=$(get_prop "remote.production.datasource.serverName")
    remote_prod_db=$(get_prop "remote.production.datasource.databaseName")
    remote_prod_user=$(get_prop "remote.production.datasource.user")
    remote_prod_pass=$(get_prop "remote.production.datasource.password")
    remote_prod_port=$(get_prop "remote.production.datasource.port")

    if [[ $remote_prod_host = "" ]]; then
        remote_prod_port=$default_port;
    fi

    # Remote machine user for SSH
    remote_user=$(get_prop "remote.user")
}

build() {
    if [[ "$verbose" = true ]]; then
        # TODO: improve verbose
        set -x
    fi

    load_properties

    if [[ "$docker" = true ]]; then
        echo "$local_prod_host:$local_prod_port:*:$local_prod_user:$local_prod_pass" > ~/.pgpass
        echo "$remote_prod_host:$remote_prod_port:*:$remote_prod_user:$remote_prod_pass" >> ~/.pgpass
        chmod 0600 ~/.pgpass
    fi  # TODO: else should check if pgpass file exists

    if [[ "$skip_install" = false ]]; then
        if [[ -f $sources_path/gradlew ]]; then
            mine_dir=$(pwd)
            echo "--- Cleaning sources ---"
            cd $sources_path
            ./gradlew clean
            ./gradlew install --stacktrace
            cd $mine_dir
        else
            echo "Error: couldn't find sources folder gradlew file, path tried: $sources_path/gradlew install" >&2
            exit 1
        fi
    fi

    if [[ -f ./gradlew ]]; then
        echo "--- Cleaning mine ---"
        ./gradlew clean --stacktrace
        echo "--- Building DB ---"
        ./gradlew buildDB --stacktrace
        
        if [[ "$skip_sources" = false ]]; then
            if [ "$sources" = "" ]; then   # All sources
                # Getting the sources in order from the project file
                for fp in $(perl -ne 'while(/<source +name="([^"]+)"/g){print "$1\n";}' project.xml); do
                    echo "------------- Source: $(basename $fp) -------------"
                    ./gradlew integrate -Psource=$(basename $fp) --stacktrace
                done
            else    # List of sources passed as cmd-line arg
                for j in ${sources//,/ }
                do
                    echo "------------- Source: $j -------------"
                    ./gradlew integrate -Psource=$j --stacktrace
                done
            fi

            # ./gradlew postprocess --stacktrace
            ./gradlew postprocess -Pprocess=do-sources --stacktrace
            ./gradlew postprocess -Pprocess=create-attribute-indexes --stacktrace
            ./gradlew postprocess -Pprocess=summarise-objectstore --stacktrace
        fi

        if [[ "$deploy_remote" = true ]]; then
            echo "Dumping local DB"
            pg_dump -h "$local_prod_host" -p "$local_prod_port" -U "$local_prod_user" -d "$local_prod_db" -F c > ./mdrmine_build.sql

            echo "Transfer local build to remote machine"
            pg_restore --clean -h "$remote_prod_host" -p "$remote_prod_port" -U "$remote_prod_user" -d "$remote_prod_db" ./mdrmine_build.sql
            # TODO: add something to backup old DB

            # TODO: should check that Docker is running on remote?
            # TODO: option to run only this part if failed?
            # TODO: remote mdrmine path should be an arg
            # Run solr postprocesses on remote
            ssh $remote_user@$remote_prod_host -o StrictHostKeyChecking=no <<EOF
                cd ./code/mdrmine;
                docker build -f Dockerfiles/main/Dockerfile --target mdrmine_postprocess -t mdrmine_postprocess .;
                docker run --mount type=bind,src=/home/ubuntu/.intermine,dst=/root/.intermine --network=mdrmine_default mdrmine_postprocess;
EOF
        else
            ./gradlew postprocess -Pprocess=create-autocomplete-index --stacktrace
            ./gradlew postprocess -Pprocess=create-search-index --stacktrace
        fi
            
        ./gradlew buildUserDB --stacktrace
        if [[ "$docker" = true ]]; then
            # Generate war file
            ./gradlew war
            cp ./webapp/build/libs/webapp.war /webapps/mdrmine.war
        elif [[ "$first_build" = false ]]; then
            ./gradlew cargoRedeployRemote --stacktrace
        else
            ./gradlew cargoDeployRemote --stacktrace
        fi
    else
        echo "Error: couldn't find gradlew file, make sure you run the script for the root MDRMine folder." >&2
        exit 1
    fi
}

# Parsing command-line arguments
for i in "$@"; do
  case $i in
    -h | --help)
        usage
        exit 0
        ;;
    -c=*|--properties-path=*)
        properties_path="${i#*=}"
        shift
        ;;
    -d | --docker)
        docker=true
        shift
        ;;
    -f | --first-build)
        first_build=true
        shift
        ;;
    -n=*|--hostname=*)
        hostname="${i#*=}"
        shift
        ;;
    -p=*|--path=*)
        sources_path="${i#*=}"
        shift
        ;;
    -r | --deploy-remote)
        deploy_remote=true
        shift
        ;;
    -s=*|--sources=*)
        sources="${i#*=}"
        shift
        ;;
    -v | --verbose)
        verbose=true
        shift
        ;;
    -x | --skip-install)
        skip_install=true
        shift
        ;;
    -z | --skip-sources)
        skip_sources=true
        shift
        ;;
    -*|--*)
        echo "Error: invalid option '$i'" >&2
        usage
        exit 1
        ;;
  esac
done

build