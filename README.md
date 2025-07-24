# MDRMine

TODO

## Data sources
The data sources and their corresponding data files are defined in the `project.xml` file.

See the [sources wiki](https://github.com/ecrin-github/mdrmine-bio-sources/wiki) for more details.

## Requirements
- `iptables -A ufw-user-input -p tcp -m tcp --dport 8080 -j ACCEPT` and `iptables -A ufw-user-input -p udp -m udp --dport 8080 -j ACCEPT` firewall rules on the webapp machine for Tomcat (running on 8080) to allow BlueGenes queries (e.g. user login)
- [Forked version of InterMine](https://github.com/ecrin-github/intermine) to fix an issue during the merging of sources
    - compiling of JARs required (see [Usage](#usage))

## Docker deployment
Note: the current GH action to build and deploy on a remote machine is outdated (missing InterMine fork JARs) and should not be used. 
### Required configuration
- Java for compiling sources: `openjdk 11.0.23`
- Docker secrets files
    - Create `mdrmine/secrets` folder
        - Create `postgres_user` `postgres_password` `tomcat_user` `tomcat_password` files in this folder with your Postgres and Tomcat credentials inside the various files
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
    - Add a `remote.user` property to `mdrmine.properties` corresponding to the username on the remote machine, whose hostname is taken from `remote.production.datasource.serverName`, to build and run a docker container on the remote machine (with SSH) to perform solr postprocesses
    - Finally, you will need a ssh-agent running that allows to connect to the remote machine with just `ssh user@hostname`, see [guide here](https://www.ssh.com/academy/ssh/agent)

### Usage
- `gradlew install` or `update_jars_local.sh` **in the InterMine fork folder** required to compile the forked InterMine code
- `update_jars_local.sh` from the [sources repository](https://github.com/ecrin-github/mdrmine-bio-sources) to generate the sources JARs and move them to the MDRMine folder
- `docker compose build --no-cache && docker compose up` to build and run docker images
    - possible to pass a `SOURCES` environment variable to choose sources to build
    - possible to pass a `LOCAL` environment variable with any value to not pass the --deploy-remote flag to the build script (which is the default behaviour)
-  `docker compose down --volumes --rmi "local"` to stop and delete running docker images (+ volumes)

### Caveats
- Currently the sources jars fetched from the [MDRMine-bio-sources](https://github.com/ecrin-github/mdrmine-bio-sources) repository artifacts must match the configuration of `<sources>` in the `project.xml` file, other Intermine will throw errors.
- TODO: Probably other caveats regarding properties, build script, and compose file
