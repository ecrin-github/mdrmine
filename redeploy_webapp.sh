#!/bin/bash

# docker build -f Dockerfiles/main/Dockerfile --target mdrmine_webapp -t mdrmine_webapp .
# docker run --mount type=bind,src=/home/ubuntu/.intermine,dst=/root/.intermine --volume mdrmine_webapps:/webapps --network=mdrmine_default mdrmine_webapp

./gradlew war
rm /webapps/mdrmine.war
cp ./webapp/build/libs/webapp.war /webapps/mdrmine.war