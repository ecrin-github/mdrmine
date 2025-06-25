#!/bin/bash

# Default variable values
deploy_remote=false
docker=false
verbose=false

usage() {
    echo "Run MDRMine solr postprocesses"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -d, --docker                                                             (TODO)"
    echo " -r, --deploy-remote                                                      (TODO)"
    echo " -v, --verbose                                                            Enable verbose mode (TODO, outputs commands)"
}

postprocess() {
    if [[ "$verbose" = true ]]; then
        # TODO: improve verbose
        set -x
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