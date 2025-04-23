#!/bin/bash

# Default variable values
sources_path="/home/ubuntu/code/mdrmine-bio-sources"
sources=""
skip_install=false
first_build=false
docker=false
verbose=false
update_publications=false

usage() {
    echo "Build and deploy MDRMine."
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -d, --docker                                                 Instead of ./gradlew cargoDeployRemote, uses a shared Docker volume to deploy webapp .war file"
    echo " -f, --first-build                                            Replaces ./gradlew cargoRedeployRemote by ./gradlew cargoDeployRemote"
    echo " -p=[sources_path], --path=[sources_path]                     Set sources repo path, default: $sources_path"
    echo " -s=[list of comma separated sources], --sources=[sources]    Set list of sources to integrate, default behaviour includes all in sources folder"
    echo " -u, --update-publications                                    After integrating the sources, fetch PubMed articles from DB-inserted PMIDs"
    echo " -v, --verbose                                                Enable verbose mode (outputs commands)"
    echo " -x, --skip-install                                           Skip ./gradlew install in bio-sources repository"
}

build() {
    if [[ "$verbose" = true ]]; then
        # TODO: improve verbose
        set -x
    fi

    if [[ "$skip_install" = false ]]; then
        if [[ -f $sources_path/gradlew ]]; then
            $sources_path/gradlew install --stacktrace
        else
            echo "Error: couldn't find sources folder gradlew file, path tried: $sources_path/gradlew install" >&2
            exit 1
        fi
    fi

    if [[ -f ./gradlew ]]; then
        ./gradlew clean --stacktrace
        ./gradlew buildDB --stacktrace
        
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

        # PubMed data
        if [[ "$update_publications" = true ]]; then
            ./gradlew integrate -Psource=update-publications --stacktrace
        fi
        ./gradlew postProcess --stacktrace
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
    -x | --skip-install)
        skip_install=true
        shift
        ;;
    -f | --first-build)
        first_build=true
        shift
        ;;
    -d | --docker)
        docker=true
        shift
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
    -u | --update-publications)
        update_publications=true
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