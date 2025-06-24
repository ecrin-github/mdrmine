#!/bin/bash

# Default variable values
properties_path="/root/.intermine/mdrmine.properties"
deploy_remote=false
docker=false
verbose=false

usage() {
    echo "Run MDRMine solr postprocesses"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -c=[properties_path], --properties-path=[properties_path]                Set properties file path, default: $properties_path"
    echo " -d, --docker                                                             (TODO)"
    echo " -r, --deploy-remote                                                      (TODO)"
    echo " -v, --verbose                                                            Enable verbose mode (TODO, outputs commands)"
}

postprocess() {
    if [[ "$verbose" = true ]]; then
        # TODO: improve verbose
        set -x
    fi

    # Copy bind-mounted properties to be able to edit them without changing the original files
    cp -r /root/.intermine_base /root/.intermine

    if [[ -f ./compose.yaml ]]; then
        # TODO: this is for non-docker
        # Setting correct port in properties file (external), this is assuming that the internal port will be 5432
        # TODO: should check that db.production.datasource.port is not already set
        external_port=$(grep -Eo "[[:digit:]]+:5432\"" compose.yaml | cut -d ':' -f1)
        echo "db.production.datasource.port=$external_port" >> /root/.intermine/mdrmine.properties
        
        # Setting correct hostname 
        hostname_regex="HOSTNAME:[[:space:]]*([^\n[:space:]]*)([[:space:]][^\n]*)?"
        if [[ $(cat ./compose.yaml) =~ $hostname_regex ]]; then
            hostname="${BASH_REMATCH[1]}"
            if [ "$hostname" != "localhost" ]; then 
                sed -i "s/serverName=localhost/serverName=$hostname/" /root/.intermine/mdrmine.properties
            fi
        fi
    else
        echo "Couldn't find compose.yaml file in the current directory"
        exit 1
    fi

    if [[ -f ./gradlew ]]; then
        ./gradlew clean
        # ./gradlew dbmodel:initConfig --stacktrace
        # ./gradlew dbmodel:copyMineProperties --stacktrace
        # ./gradlew dbmodel:copyDefaultInterMineProperties --stacktrace
        # ./gradlew dbmodel:jar --stacktrace
        # ./gradlew dbmodel:generateKeys --stacktrace

        ./gradlew postprocess -Pprocess=create-autocomplete-index --stacktrace
        ./gradlew postprocess -Pprocess=create-search-index --stacktrace
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
    -r | --deploy-remote)
        deploy_remote=true
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

postprocess