#!/bin/bash
# Note: docker only

# docker build -f Dockerfiles/main/Dockerfile --target mdrmine_summary -t mdrmine_summary .
# docker run --mount type=bind,src=/home/ubuntu/.intermine,dst=/root/.intermine_base --volume mdrmine_webapps:/webapps --network=mdrmine_default mdrmine_summary

# Set MDRMine Docker properties
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
$SCRIPT_DIR/set_docker_properties.sh

./gradlew postprocess -Pprocess=summarise-objectstore --stacktrace

./gradlew war
rm /webapps/mdrmine.war
cp ./webapp/build/libs/webapp.war /webapps/mdrmine.war