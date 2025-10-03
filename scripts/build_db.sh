#!/bin/bash

# Default variable values
verbose=false

usage() {
    echo "Run MDRMine solr postprocesses"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -h, --help                                                   Show this text"
    echo " -v, --verbose                                                            Enable verbose mode (TODO, outputs commands)"
}

buildDB() {
    if [[ "$verbose" = true ]]; then
        # TODO: improve verbose
        set -x
    fi

    # Set MDRMine Docker properties
    SCRIPT_PATH=$(readlink -f "$0")
    SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
    $SCRIPT_DIR/set_docker_properties.sh

    if [ $? = 1 ];  # Exiting if script returned an error code
    then
        exit 1
    fi

    if [[ -f ./gradlew ]]; then
        ./gradlew clean
        ./gradlew buildDB --stacktrace
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

buildDB