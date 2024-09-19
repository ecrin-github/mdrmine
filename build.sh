#!/bin/bash

# Default variable values
sources_path="/home/ubuntu/code/mdrmine-bio-sources"
sources="auto"

usage() {
    echo "Build and deploy MDRMine."
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -v, --verbose                                                Enable verbose mode (outputs commands)"
    echo " -p=[sources_path], --path=[sources_path]                     Set sources repo path, default: $sources_path"
    echo " -s=[list of comma separated sources], --sources=[sources]    Set list of sources to integrate, default behaviour includes all in sources folder"
}

build() {
    if [[ "$verbose" = true ]]; then
        # TODO: improve verbose
        set -x
    fi

    if [[ -f $sources_path/gradlew ]]; then
        $sources_path/gradlew install
    else
        echo "Error: couldn't find sources folder gradlew file, path tried: $sources_path/gradlew install" >&2
        exit 1
    fi

    if [[ -f ./gradlew ]]; then
        ./gradlew clean
        ./gradlew buildDB
        if [ "$sources" = "auto" ]; then
            # Default mode for integrating sources (auto sources detection)
            for fp in $sources_path/*; do
                if [[ -d $fp && -d $fp/src/main/java/org/intermine/bio/dataconversion ]]; then
                    ./gradlew integrate -Psource=$(basename $fp) --stacktrace
                fi
            done
        else
            # List of sources passed as cmd-line arg
            IFS=',' read -ra SRCS <<< "$sources"
            for fn in "${SRCS[@]}"; do
                if [[ -d $sources_path/$fn/src/main/java/org/intermine/bio/dataconversion ]]; then
                    ./gradlew integrate -Psource=$(basename $fn) --stacktrace
                else
                    echo "Warning: ignoring source $fn, couldn't find path $sources_path/$fn/src/main/java/org/intermine/bio/dataconversion"
                fi
            done
        fi
        ./gradlew cargoRedeployRemote
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
    -p=*|--path=*)
        sources_path="${i#*=}"
        shift
        ;;
    -s=*|--sources=*)
        sources="${i#*=}"
        shift
        ;;
    -*|--*)
        echo "Invalid option: $i" >&2
        usage
        exit 1
        ;;
  esac
done

build