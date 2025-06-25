#!/bin/bash

# TODO: refactor this with other scripts

# Copy bind-mounted properties to be able to edit them without changing the original files
cp -r /root/.intermine_base /root/.intermine

# Setting correct hostname 
hostname_regex="HOSTNAME:[[:space:]]*([^\n[:space:]]*)([[:space:]][^\n]*)?"
if [[ $(cat ./compose.yaml) =~ $hostname_regex ]]; then
    hostname="${BASH_REMATCH[1]}"
    if [ "$hostname" != "localhost" ]; then 
        sed -i "s/serverName=localhost/serverName=$hostname/" /root/.intermine/mdrmine.properties
    fi
fi

./gradlew war
rm /webapps/mdrmine.war
cp ./webapp/build/libs/webapp.war /webapps/mdrmine.war