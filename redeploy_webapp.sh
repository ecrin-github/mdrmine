#!/bin/bash
# Note: docker only

# docker build -f Dockerfiles/main/Dockerfile --target mdrmine_webapp -t mdrmine_webapp .
# docker run --mount type=bind,src=/home/ubuntu/.intermine,dst=/root/.intermine --volume mdrmine_webapps:/webapps --network=mdrmine_default mdrmine_webapp

# Set MDRMine Docker properties
./set_docker_properties.sh
if [ $? = 1 ];  # Exiting if script returned an error code
then
    exit 1
fi

./gradlew war
rm /webapps/mdrmine.war
cp ./webapp/build/libs/webapp.war /webapps/mdrmine.war