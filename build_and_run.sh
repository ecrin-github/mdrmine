#!/bin/bash

# Default variable values
sources_path="/home/ubuntu/code/mdrmine-bio-sources"
sources="auto"
skip_install=false
first_build=false
docker=false

usage() {
    echo "Build and deploy MDRMine."
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -v, --verbose                                                Enable verbose mode (outputs commands)"
    echo " -x, --skip-install                                           Skip ./gradlew install in bio-sources repository"
    echo " -f, --first-build                                            Skip ./gradlew clean and replaces ./gradlew cargoRedeployRemote by ./gradlew cargoDeployRemote"
    echo " -d, --docker                                                 Instead of ./gradlew cargoDeployRemote, uses a shared Docker volume to deploy webapp .war file"
    echo " -p=[sources_path], --path=[sources_path]                     Set sources repo path, default: $sources_path"
    echo " -s=[list of comma separated sources], --sources=[sources]    Set list of sources to integrate, default behaviour includes all in sources folder"
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
        if [[ "$first_install" = false ]]; then
            ./gradlew clean --stacktrace
        fi
        ./gradlew buildDB --stacktrace
        if [[ "$skip_install" = true ]]; then
            for fp in ~/.m2/repository/org/intermine/bio-source-*; do
                if [[ -d $fp && $(basename $fp) =~ (bio-source-)(.*$) ]]; then
                    echo ${BASH_REMATCH[2]}
                    ./gradlew integrate -Psource=${BASH_REMATCH[2]} --stacktrace
                fi
            done
        else
            if [ "$sources" = "auto" ]; then
                # Default mode for integrating sources (auto sources detection)
                for fp in $sources_path/*; do
                    # TODO: how to select the sources--> with the jars
                    if [[ "$skip_install" = true ]]; then
                        if [[ -d $fp && -d $fp/src/main/java/org/intermine/bio/dataconversion ]]; then
                            ./gradlew integrate -Psource=$(basename $fp) --stacktrace
                        fi
                    else
                        if [[ -d $fp && -d $fp/src/main/java/org/intermine/bio/dataconversion ]]; then
                            ./gradlew integrate -Psource=$(basename $fp) --stacktrace
                        fi
                    fi
                done
            else
                # List of sources passed as cmd-line arg
                j=1
                while fn=$(echo "$sources"|cut -d "," -f $j) ; [ -n "$fn" ] ;do
                    if [[ -d $sources_path/$fn/src/main/java/org/intermine/bio/dataconversion ]]; then
                        ./gradlew integrate -Psource=$(basename $fn) --stacktrace
                    else
                        echo "Warning: ignoring source $fn, couldn't find path $sources_path/$fn/src/main/java/org/intermine/bio/dataconversion"
                    fi
                    j=$((j+1))
                done
            fi
        fi
        # TODO: include this after solr has been set up
        # ./gradlew postProcess --stacktrace
        # TODO: include this?
        ./gradlew buildUserDB --stacktrace

        if [[ "$docker" = true ]]; then
            # Generate war file
            ./gradlew war
            cp ./webapp/build/libs/webapp.war /webapps/mdrmine.war
            # TODO: remove
            sleep 10000
        else
            if [[ "$local" = true ]]; then
                if [[ "$first_install" = false ]]; then
                    ./gradlew cargoRedeployLocal --stacktrace
                else
                    ./gradlew cargoStartLocal --stacktrace
                fi
            else
                if [[ "$first_install" = false ]]; then
                    ./gradlew cargoRedeployRemote --stacktrace
                else
                    ./gradlew cargoDeployRemote --stacktrace
                fi
            fi
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
    -*|--*)
        echo "Error: invalid option '$i'" >&2
        usage
        exit 1
        ;;
  esac
done

build