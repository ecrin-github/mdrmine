# syntax=docker/dockerfile:1

FROM solr:latest

COPY scripts/start_solr.sh ./

# Needed for allowing /solr_backups as a path to backup the data
COPY solr/solr.xml /var/solr/data/solr.xml

# Unfortunately needed to fix an issue where allowPaths variable expansion 
# does not seem to work and there are no permissions to do anything in paths folders in allowPaths
COPY solr/security.policy /opt/solr/server/etc/security.policy

ENTRYPOINT "./start_solr.sh"