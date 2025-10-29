#!/bin/bash

# Default variable values
who_fp=/home/ubuntu/data/who/who.csv
docker=false
verbose=false

usage() {
    echo "Preprocess WHO data file, if the file is a simlink, replaces the current WHO symlink with the preprocessed file"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -f, --file-who                                                           Path to WHO data file, default: $who_fp"
}

preprocess() {
    if [[ "$verbose" = true ]]; then
        # TODO: improve verbose
        set -x
    fi

    if [[ -e $who_fp ]]; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        who_dir="$(dirname "$who_fp")"
        dest_file=$who_dir/$timestamp\_preprocessed\_who.csv

        # Replace any backslash or multiple backslashes followed by a double quote by just a double quote
        sed -E 's/\\+\"/"/g' $who_fp > $dest_file
        echo "Created preprocessed file $dest_file"
        if [[ -L $who_fp ]]; then   # Symbolic link
            rm $who_fp
            ln -s $dest_file $who_fp
            echo "Replaced $who_fp symlink to point to $dest_file"
        fi
    else
        echo "Error: couldn't find WHO data file at path $who_fp" >&2
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
    -f=*|--file-who=*)
        hostname="${i#*=}"
        shift
        ;;
    -*|--*)
        echo "Error: invalid option '$i'" >&2
        usage
        exit 1
        ;;
  esac
done

preprocess