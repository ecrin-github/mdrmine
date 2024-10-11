# TODO

## Docker deployment
### Required configuration
- Docker secrets files
    - Create `mdrmine/secrets` folder
        - Create `postgres_user` `postgres_password` `tomcat_user` `tomcat_password` files in this folder with your Postgres and Tomcat credentials inside the various files
    - Create `.intermine` folder in `home` user directory (`~`)
        - Create `mdrmine.properties` file following the model here: [BioTestMine properties file](https://raw.githubusercontent.com/intermine/biotestmine/master/data/biotestmine.properties).
        The dbs `serverName` properties should be set to `db`, as that is the psql image name in the Docker compose file. The various credentials should match the ones used in the `secrets/` files. Finally, replace all occurrences of "`biotestmine`" with "`mdrmine`".
        - Create `bluegenes.env` file in this folder, with a config like this:
            ``` 
            BLUEGENES_DEFAULT_SERVICE_ROOT=http://{your_machine's_ip}:8080/mdrmine
            BLUEGENES_DEFAULT_MINE_NAME=mdrmine
            BLUEGENES_DEFAULT_NAMESPACE=mdrmine
            SERVER_PORT=8090
            ```
            If you want to change the ports used, you need to modify them here and in `mdrmine/compose.yaml` as well.
### Caveats
- Currently the sources jars fetched from the [MDRMine-bio-sources](https://github.com/ecrin-github/mdrmine-bio-sources) repository artifacts must match the configuration of `<sources>` in the `project.xml` file, other Intermine will throw errors.
