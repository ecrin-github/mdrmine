# syntax=docker/dockerfile:1
ARG EMPTY=false
ARG LOCAL=false
ARG HOSTNAME=localhost
ARG SOURCES=""

# TODO: change to java 11 image?
FROM ubuntu:latest AS mdrmine_env
WORKDIR /mdrmine

ARG EMPTY
ARG LOCAL
ARG HOSTNAME
ARG SOURCES
ENV SOURCES=${SOURCES}
ENV HOSTNAME=${HOSTNAME}
ENV EMPTY=${EMPTY:+--build-empty}
ENV DEPLOY_REMOTE=${LOCAL:---deploy-remote}

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

# Setting more memory to avoid OutOfMemoryError on WHO
# Note: enabling daemon causes an error (additions files not found)
# ENV GRADLE_OPTS="-server -Xms2g -Xmx16g -XX:+UseParallelGC -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99 -Dorg.gradle.daemon=false"
# -Xms2g: initial heap size available to the JVM; -Xmx16g: maximum heap size available to the JVM
ENV GRADLE_OPTS="-server -Xms2g -Xmx58g -XX:+UseParallelGC -XX:SoftRefLRUPolicyMSPerMB=1 -XX:MaxHeapFreeRatio=99 -Dorg.gradle.daemon=false"
RUN export GRADLE_OPTS

# Installing Java
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk postgresql-client ssh && \
    apt-get clean;
ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64/"

# TODO: run docker compose up in FG in deploy.yml but tomcat in background?
# TODO: try to change Docker secret files permissions
# TODO: memcached somwhere? https://hub.docker.com/_/memcached
# docker rmi $(docker images --filter "dangling=true" -q --no-trunc)


FROM mdrmine_env AS mdrmine_build

ENTRYPOINT ./build_and_run.sh --skip-install --first-build --docker ${DEPLOY_REMOTE} ${EMPTY} --sources=${SOURCES} --hostname=${HOSTNAME}


FROM mdrmine_env AS mdrmine_postprocess
ENV HOSTNAME="db"

ENTRYPOINT ./postprocess.sh


FROM mdrmine_env AS mdrmine_webapp

ENTRYPOINT ./redeploy_webapp.sh