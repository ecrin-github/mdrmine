#!/bin/bash

# Reading list of allowed IPs from Docker secret file
export SOLR_IP_ALLOWLIST=$(cat "$SOLR_IP_ALLOWLIST_FILE")
export SOLR_OPTS="$SOLR_OPTS -Dsolr.allowUrls=$(cat "$SOLR_URL_ALLOWLIST_FILE")"

mkdir -p /solr_backups/data
chown -R 8983:8983 /solr_backups

mkdir -p /var/solr/data
chown -R 8983:8983 /var/solr/data

if [ "$SOLR_ROLE" = "leader" ]; then
  CONFIGSET=/opt/solr/server/solr/configsets/leader
else
  CONFIGSET=/opt/solr/server/solr/configsets/follower
fi

runuser -u solr -- precreate-core mdrmine-search "$CONFIGSET"
runuser -u solr -- precreate-core mdrmine-autocomplete "$CONFIGSET"

runuser -u solr -- solr -f -Dvelocity.solr.resource.loader.enabled=true