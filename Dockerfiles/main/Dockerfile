# syntax=docker/dockerfile:1

FROM ubuntu:latest AS main
WORKDIR /mdrmine

ARG SOURCES=""
ENV SOURCES ${SOURCES}

ENV LANG=C.UTF-8
ENV JARS_PATH="./sources_jars"

# Copy from context dir (repo outside container) to working dir (container), see https://stackoverflow.com/a/58434551/23455986
COPY . .
# Replace project.xml by dev file
RUN if [ -f ./dev_env ]; then rm project.xml && mv project_dev.xml project.xml ; fi
# Modify solr URLs to work with docker (domain is image name in compose instead of localhost)
RUN sed -i 's/localhost/solr/' /mdrmine/dbmodel/resources/keyword_search.properties \
 && sed -i 's/localhost/solr/' /mdrmine/dbmodel/resources/objectstoresummary.config.properties
# Move sources jars to directory Intermine uses
# TODO: add check of sources in project.xml?
RUN if [ -n "$( ls -A "$JARS_PATH" )" ]; then mkdir -p ~/.m2/repository/org/intermine/ && mv "$JARS_PATH"/* ~/.m2/repository/org/intermine/ ; fi

# TODO: change OPTS to set more memory?
# GRADLE_OPTS="-server -Xmx8g -XX:+UseParallelGC -Xms2g -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99 -Dorg.gradle.daemon=false"
ENV GRADLE_OPTS="-Dorg.gradle.daemon=false"
RUN export GRADLE_OPTS

# Installing Java
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk && \
    apt-get clean;
ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64/"

# TODO: run docker compose up in FG in deploy.yml but tomcat in background?
# TODO: remove down --volumes on every run? deploy.yml
# TODO: add params for sources selection
# TODO: try to change Docker secret files permissions
# TODO: memcached somwhere? https://hub.docker.com/_/memcached
# docker rmi $(docker images --filter "dangling=true" -q --no-trunc)

CMD exec ./build_and_run.sh --skip-install --first-build --docker --update-publications --sources=${SOURCES}
# CMD ["./build_and_run.sh", "--skip-install", "--first-build", "--docker", "--update-publications", "--sources=${SOURCES}"]