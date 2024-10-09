# syntax=docker/dockerfile:1

FROM ubuntu:latest AS main
WORKDIR /mdrmine

# TODO: test
ENV LANG C.UTF-8
ENV JARS_PATH="./sources_jars"

# Copies from context dir (repo outside container) to working dir (container), see https://stackoverflow.com/a/58434551/23455986
COPY . .
# Move sources jars to directory Intermine uses
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


# TODO: set encoding to fix mdrmine sources errors?

# TODO: solr

# TODO: document all the external files needed

# TODO: db backup? for user accounts (saved queries, etc.)

# TODO: clone intermine for it not to download every run?

# TODO: perl modules?
# RUN apt-get update && apt-get install -y \
#     libxml-writer-perl \
#     libxml-sax-base-perl \
#     libxml-perl \
#     libxml-filter-saxt-perl \

# TODO: memcached somwhere? https://hub.docker.com/_/memcached

CMD ["./build_and_run.sh", "--skip-install", "--first-build", "--docker"]