# MDRMine
Clinical MetaData Repository based on Intermine, aggregating data from different sources into a common [metadata model](https://zenodo.org/records/8368709).

## Data sources
The data sources and their corresponding data files are defined in the `project.xml` file.

See the [sources wiki](https://github.com/ecrin-github/mdrmine-bio-sources/wiki) for more details regarding the parsing and merging of the various sources.

## Requirements
- If not to be used with Docker, required software is listed on the [InterMine Docs](http://intermine.org/im-docs/docs/get-started/tutorial/index/?highlight=update~publications#software)
- `iptables -A ufw-user-input -p tcp -m tcp --dport 8080 -j ACCEPT` and `iptables -A ufw-user-input -p udp -m udp --dport 8080 -j ACCEPT` firewall rules on the webapp machine for Tomcat (running on 8080) to allow BlueGenes queries (e.g. user login)
- [Forked version of InterMine](https://github.com/ecrin-github/intermine) to fix an issue during the merging of sources
    - compiling of JARs required (see [Usage](#usage))
- Run Solr with a list of IPs allowed to query it, for example through the `SOLR_IP_ALLOWLIST` environment variable, for security reasons
- The build process, especially for sources with big data files such as WHO, can use a lot of RAM, (40+ GB), so a machine with a lot of RAM is required to perform a full build

## Docker deployment
Note: the current GH action to build and deploy on a remote machine is outdated and should not be used. 
### Required configuration
- Java for compiling sources: `openjdk 11.0.23`
- Docker secrets files
    - Create `mdrmine/secrets` folder
        - Create `postgres_user` `postgres_password` `tomcat_user` `tomcat_password` files in this folder with your Postgres and Tomcat credentials inside the various files
        - Create `solr_ip_allowlist` file in this folder with a comma-separated list of IPs allowed to send queries to solr, must include Docker compose network IP range (see `mdrmine/compose.yaml`)
    - Create `.intermine` folder in `home` user directory (`~`)
        - Create a `mdrmine.properties` or `mdrmine_docker.properties` (`mdrmine_docker.properties` will be used if both exist) file following the model here: [BioTestMine properties file](https://raw.githubusercontent.com/intermine/biotestmine/master/data/biotestmine.properties).
        The `serverName` properties should be set to `db`, as that is the psql image name in the Docker compose file. The other various credentials should match the ones used in the `secrets/` files. Replace all occurrences of "`biotestmine`" with "`mdrmine`".
        - Create `bluegenes.env` file in this folder, with a config like this:
            ``` 
            BLUEGENES_DEFAULT_SERVICE_ROOT=http://{your_machine's_ip}:8080/mdrmine
            BLUEGENES_DEFAULT_MINE_NAME=mdrmine
            BLUEGENES_DEFAULT_NAMESPACE=mdrmine
            SERVER_PORT=8090
            ```
            If you want to change the ports used, you need to modify them here and in `mdrmine/compose.yaml` as well.
- **If to be used for local build and deployment on remote machine**:
    - Add the following properties to `mdrmine.properties` to connect to the psql instance on the remote machine and pg_restore the local build to the remote db: `remote.production.datasource.serverName`, `remote.production.datasource.databaseName`, `remote.production.datasource.user`, `remote.production.datasource.password`, `remote.production.datasource.port`
    - Add a `remote.user` property to `mdrmine.properties` corresponding to the username on the remote machine, whose hostname is taken from `remote.production.datasource.serverName`, to dump and transfer both the MDRMine DB and Solr cores as well as to build and run a docker container on the remote machine (with SSH) to re-deploy the webapp
    - Finally, you will need a ssh-agent running that allows to connect to the remote machine with just `ssh user@hostname`, see [guide here](https://www.ssh.com/academy/ssh/agent)
    - **IMPORTANT**: a MDRMine instance must be running on the remote machine for the remote deployment to work, you can build an empty MDRMine for this (see [Usage](#usage))
    - Currently, some properties regarding remote deployment are still hardcoded, see `scripts/deploy_remote.sh` for more details.

### Usage
- `gradlew install` or `update_jars_local.sh` **in the InterMine fork folder** required to compile the forked InterMine code
- `update_jars_local.sh` from the [sources repository](https://github.com/ecrin-github/mdrmine-bio-sources) to generate the sources JARs and move them to the MDRMine folder
- `docker compose build --no-cache && docker compose up` to build and run docker images
    - Use the `SOURCES` environment variable to choose sources to build (by default all sources defined in `project.xml` are used)
    SOURCES: $SOURCES
        DEPLOY_REMOTE: $DEPLOY_REMOTE
        EMPTY: $EMPTY
    - Use the `DEPLOY_REMOTE` environment variable with any value to deploy the build to a remote machine after the build is finished (see `scripts/deploy_remote.sh`)
    - Use the `EMPTY` environment variable with any value to build without any source (useful to start MDRMine on the remote machine and receive a build later)
- `docker compose down --volumes --rmi "local"` to stop and delete running docker images (+ volumes)
- `docker compose up -d --no-deps --build <service_name>` to re-build and run a specific service (image) on an already running MDRMine

The main MDRMine Dockerfile (`Dockerfiles/main/Dockerfile`) has multiple stages based on the same base image with the environment required to run MDRMine. These various stages can be run individually to perform certain actions:
- `docker build -f Dockerfiles/main/Dockerfile --target <stage_name> -t <stage_name> .`
- `docker run --mount type=bind,src=<.intermine_folder_path>,dst=/root/.intermine_base --volume mdrmine_webapps:/webapps --network=mdrmine_default <stage_name>`
    - The destination folder for the .intermine bind mount must be /root/.intermine_base, to not modify the mounted properties files and modify copied ones instead

These are the stages:
- `mdrmine_build`, the default stage when building and running Docker compose, which builds MDRMine
- `mdrmine_builddb`, used to rebuild the MDRMine DB, useful on a remote machine to update to a schema change before receiving a new build (used in `scripts/deploy_remote.sh`)
- `mdrmine_webapp`, used to rebuild the webapp, for example after transfering a build to a remote machine (used in `scripts/deploy_remote.sh`)

Note: the only requirement regarding the order in which the sources should be parsed, is that **WHO needs to be parsed after CTG and CTIS**, because WHO needs stored studies from previous sources which may have multiple IDs between the CTIS ID, NCT ID, and EUCTR ID, to extract these and match with WHO records in order to "pre-merge", to avoid duplicate errors. For example, if 2 studies in WHO are the same but are not linked by any ID (one has an EUCTR ID, the other has a NCT ID), an entry in CTG could have both IDs. Therefore, if it is parsed before CTG, the entry in CTG won't know with which record to merge, and will throw an error. In WHO, we fetch all studies stored from previous sources, so if it is parsed after CTG, we will know to "pre-merge" (i.e. while parsing) the 2 studies in WHO together to match the single study in CTG.

## Caveats
- The list of sources in `.m2/org/intermine/bio-source-<source_name>` (or `sources_jars` for Docker usage) must match the configuration of `<sources>` in the `project.xml` file, other Intermine will throw errors.
- Most of the scripts are designed for use with Docker and untested for "regular" use.
- TODO: Probably other caveats regarding properties, build script, and compose file -> the various mounts and volumes

## Versioning
- [New data source].[[Model](dbmodel/resources/mdr.xml) changes].[[Sources](https://github.com/ecrin-github/mdrmine-bio-sources) code update]
