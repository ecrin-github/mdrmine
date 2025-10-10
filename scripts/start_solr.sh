#!/bin/bash

mkdir -p /solr_backups/data
chown -R 8983:8983 /solr_backups

mkdir -p /var/solr/data
chown -R 8983:8983 /var/solr/data

runuser -u solr -- precreate-core mdrmine-search
runuser -u solr -- precreate-core mdrmine-autocomplete

runuser -u solr -- solr -f -Dvelocity.solr.resource.loader.enabled=true