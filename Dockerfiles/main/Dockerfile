# syntax=docker/dockerfile:1
ARG BUILD_USER_DB=false
ARG EMPTY=false
ARG LOCAL=false
ARG HOSTNAME=localhost
ARG SOURCES=""

# docker rmi $(docker images --filter "dangling=true" -q --no-trunc)
FROM eclipse-temurin:11 AS mdrmine_env
WORKDIR /mdrmine

ARG BUILD_USER_DB
ARG EMPTY
ARG LOCAL
ARG HOSTNAME
ARG SOURCES
ENV BUILD_USER_DB=${BUILD_USER_DB:+--build-user-db}
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

# Install Postgres for pg_restore and pg_dump, and ssh for remote postprocessing/redeployment of webapp
RUN apt-get update && apt-get install -y postgresql-client ssh && apt-get clean;


# MDRMine full build process
FROM mdrmine_env AS mdrmine_build

ENTRYPOINT ./scripts/build_and_run.sh --skip-install --first-build --docker ${DEPLOY_REMOTE} ${BUILD_USER_DB} ${EMPTY} --sources=${SOURCES} --hostname=${HOSTNAME}


# Solr postprocesses
FROM mdrmine_env AS mdrmine_postprocess

ENTRYPOINT ./scripts/postprocess.sh


# Tomcat webapp redeployment
FROM mdrmine_env AS mdrmine_webapp

ENTRYPOINT ./scripts/redeploy_webapp.sh


# Solr postprocess and tomcat redeployment combined
FROM mdrmine_env AS mdrmine_deploy

ENTRYPOINT ./scripts/deploy_docker.sh