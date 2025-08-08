#!/bin/bash
# Note: called by other scripts, please don't rename/modify

# Verifying that intermine properties folder has been mounted to the right path
if [ ! -d /root/.intermine_base ]; then
    echo -n "Directory \"/root/.intermine_base\" does not exist, "
    echo "please make you sure you mounted the intermine properties directory to this path"
    exit 1
fi

# Copy bind-mounted properties to load docker properties file without modifying anything on disk
if [ ! -d /root/.intermine ]; then  # Else, we assume that another script already did the following commands
    cp -r /root/.intermine_base /root/.intermine
    if [[ -f /root/.intermine/mdrmine_docker.properties ]]; then
        rm /root/.intermine/mdrmine.properties
        mv /root/.intermine/mdrmine_docker.properties /root/.intermine/mdrmine.properties
    fi
fi