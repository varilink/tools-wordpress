# Tools - WordPress

David Williamson @ Varilink Computing Ltd

------

Provides Docker Compose services that can be used to run any WordPress based website on the desktop for development and testing.

## How to use this tool in a project

1. Add this repository as a submodule of a project that uses it. To make the project's WordPress website available in the web browser on that desktop, that project must also use my [proxy tool](https://github.com/varilink/tools-proxy).

2. Set the following Docker Compose environment variables in the project:
   - COMPOSE_PROJECT_NAME
   - WORDPRESS_TAG
   - MARIADB_TAG


3. Add any additional Docker Compose files to your project that you require in order to extend the services defined in this repository; for example in order to define additional, project specific environment variables.

4. Be sure to apply all the required Docker Compose files in the right order, which can be done using the COMPOSE_FILE environment variable for convenience.

An good example of this tool used in a project is can be found in my own [FoBV - Docker](https://github.com/varilink/fobv-docker) repository.

Note that you must include a Docker Compose file in the project's root folder **first** in the `COMPOSE_FILE` variable since this then sets the root folder for any relative paths in all the subsequent Docker Compose files - see [this issue on GitHub](https://github.com/docker/compose/issues/3874), which identifies the workaround of using an empty Docker Compose file in the project's root folder where there isn't already one in there that can be referenced first.

## Starting a project from scratch
When starting work on a project for the first time, with no existing project containers or volumes in place, simply bringing the project's `wordpress` service up via `docker-compose up wordpress` will enable you to run the WordPress installation script for your development website at `http://${COMPOSE_PROJECT_NAME}` on your desktop.

In this mode it's probable that you won't need to provide any project overrides for the Docker Compose services provided by this tool. As noted above however, the Docker Compose file listed first in the `COMPOSE_FILE` must be a project file in the project's root folder. As highlighted in the GitHub issue referenced above, this can be achieved using a Docker Compose file that is empty, save for the Docker Compose file version number; for example:

```yaml
version: "3.6"
```

The WordPress site is made available at `http://${COMPOSE_PROJECT_NAME}` by my [proxy tool](https://github.com/varilink/tools-proxy) **only** if you make an entry in your hosts file as explained under [DNS / Host name lookup](https://github.com/varilink/tools-proxy#dns--host-name-lookup) in the README for my [proxy tool](https://github.com/varilink/tools-proxy).

The WordPress installation folder is stored in a volume named wordpress, which will be created with the name `${COMPOSE_PROJECT_NAME}_wordpress`. This is because it is shared by both the wordpress and wp-cli Docker Compose services. Be alert that this means it must be explicitly removed if that's required. It can't be cleared by simply removing a container.

## Restoring a project from backup
You can restore a WordPress website from backup to work on updates to it locally. To do this you must provide a fuller, project Docker Compose file that extends the `db` and `wp-cli` services with volumes as follows:

- For the `db` service, a volume that maps a folder containing a data dump file to restore from, mapped to the folder `/docker-entrypoint-initdb.d` in the container - see under "Initialzing a fresh instance" on the [MariaDB Docker Hub page](https://hub.docker.com/_/mariadb).

- For the `wp-cli` service, a volume that maps a folder containing a compressed, tar archive (extension `.tar.gz`) of the website's WordPress installation folder.



 To do this your project must contain a folder `/backup` that has in it:

1. A dump of the website's database with one of the extensions listed

2. A compressed, tar archive (extension `.tar.gz`) of the website's WordPress files.

The restore of the database takes a little while. So, it's best to bring your project's db service up first and wait for this to happen. If you just bring the wordpress service up and let it start the db service as a dependent service before the database restore has happened then the wordpress service will be unable to connect to the database as the db service is unavailable while the restore is in progress. By the time the db service becomes available the wordpress service will have timed out. Once the database has been restored on repeat occasions that you're bringing services up you won't have to worry about this.

Almost inevitably, your backup will have been taken on an external server on which your project is accessible via a different URL to the one we use for development and testing. So, it will now be necessary to use the `_restore` helper that's built-in to the wp-cli service.

## The wp-cli service and its built-in helpers

The wp-cli access provides the [WP-CLI command line interface for WordPress](https://wp-cli.org/) accessing the same WordPress installation folder as does the wordpress service and with access to the database hosted by the db service. This can be confirmed within your project via the command `docker-compose run --rm wp-cli --help`, which of course will display the WP CLI command's help.

The service also wraps the WP CLI with helper shortcuts. These are invoked by passing it commands that are prefixed with an underscore to avoid any clash with a built-in WP CLI command. At the moment there is just one of these, `_restore`, which is invoked using the command `docker-compose run --rm wp-cli _restore`. Others may be added in due course.

Here is guidance on how to use the defined helpers:

### _correct_site_url

*Before this is done you will see a redirect to the site that the backup was taken from*


### _restore

Makes a backup from a server that has been restored on the developer desktop useable by doing a WP-CLI search-replace to change instances of the website's URL on the server to the website's URL on the developer desktop. To do this it requires that three environment variables are set:
- DOMAIN - e.g. bennerleyviaduct.org.uk
- ENVIRONMENTS - e.g. test:www
- COMPOSE_PROJECT_NAME - e.g. fobv

The helper will then run a `wp search-replace` command for each of the colon separate environments as follows:

`wp search-replace https://[environment].$DOMAIN http://$COMPOSE_PROJECT_NAME`

Since the backup will have come from one of the test or the www environment there is some redundancy here but it keeps things simple and is harmless.
