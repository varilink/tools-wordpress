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
You can restore a WordPress website from backup to work on updates to it locally. To do this you must provide a project Docker Compose file that extends the `db` and `wp-cli` services with volumes as follows:

- For the `db` service, a volume that maps a folder containing a data dump file to restore from, mapped to the folder `/docker-entrypoint-initdb.d` in the container - see under "Initialzing a fresh instance" on the [MariaDB Docker Hub page](https://hub.docker.com/_/mariadb).

- For the `wp-cli` service, a volume that maps a folder containing a compressed, tar archive (extension `.tar.gz`) of the website's WordPress installation folder.

 To do this your project must contain a folder `/backup` that has in it:

1. A dump of the website's database with one of the extensions listed

2. A compressed, tar archive (extension `.tar.gz`) of the website's WordPress files.

The restore of the database takes a little while. So, it's best to bring your project's `db` service up first and wait for this to happen. If you just bring the `wordpress` service up and let it start the `db` service as a dependent service before the database restore has happened, then the wordpress service will be unable to connect to the database as the `db` service is unavailable while the restore is in progress. By the time the `db` service becomes available the wordpress service will have timed out. Once the database has been restored on repeat occasions that you're bringing services up you won't have to worry about this.

Once the database has restored you can stop the `db` service and then bring up the `wordpress` service. You should then consider running the following `wp-cli` service helpers (see [The wp-cli service and its built-in helpers](#the-wp-cli-service-and-its-built-in-helpers) below) **before** you access the locally running website at http://*compose-project-name*:

- [_correct-site-url](#_correct-site-url)
- [_create-admin-user](#_create-admin-user)
- [_install-importer](#_install-importer)
- [_restore-theme](#_restore-theme)
- [_restore-media](#_restore-media)

Certainly it will be necessary to run [_correct-site-url](#_correct-site-url). You will need to run [_install-importer](#_install-importer) if you want to use the [_import-post](#_import-post) helper.

## The wp-cli service and its built-in helpers

The wp-cli access provides the [WP-CLI command line interface for WordPress](https://wp-cli.org/) accessing the same WordPress installation folder as does the wordpress service and with access to the database hosted by the db service. This can be confirmed within your project via the command `docker-compose run --rm wp-cli --help`, which of course will display the WP CLI command's help.

Note that your project must supply a file `wp-cli.env` within its root directory that sets the following environment variables:

- `DOMAIN` = the project's domain; for example "example.com".
- `ENVIRONMENTS` = a colon separated list of environments that you might wish to restore backups from to work on locally; for example "test:www".

The service also wraps the WP CLI with helper shortcuts. These are invoked by passing it commands that are prefixed with an underscore to avoid any clash with a built-in WP CLI command. These helpers can be invoked by passing the helper name to the `wp-cli` service; for example to run the [_correct-site-url](#_correct-site-url) helper:

```bash
docker-compose run --rm wp-cli _correct-site-url
```

You can also provide a single underscore as a command line argument to the `wp-cli`, which will output a menu list of the helpers to select from:

```bash
docker-compose run --rm wp-cli _
```

Here is guidance on each of the defined helpers:

### _correct-site-url

Any backup will have been taken from one of the environments in use for the website. This means that the links stored in the database associated with that backup will reflect this, they will start with; for example http://dev.example.com, https://test.example.com or https://www.example.com. This helper performs a search-replace within the database, replacing all such URLs with ones that start with http://*compose-project-name*.


Note that if you don't run this helper prior to accessing a website that you've restored from backup locally, then this will trigger an immediate redirect to URL associated with the backup. That redirect will be remembered in the browsers cache. So, it's important to run this helper before you try to access the website locally otherwise you will need to clear the remembered redirect.

### _create-admin-user

This creates a user within the local WordPress site with the name `admin`, the email address `admin@localhost.localdomain`, the role `administrator` and the password `password`. Of course this can then be used to work in the WordPress dashboard locally with administrator privilege without having to know any of the logins that were restored from backup.

### _export-post

### _import-post

### _install-importer

### remove-contact-form-recaptcha-integration

### _restore-media

Makes a backup from a server that has been restored on the developer desktop useable by doing a WP-CLI search-replace to change instances of the website's URL on the server to the website's URL on the developer desktop. To do this it requires that three environment variables are set:
- DOMAIN - e.g. bennerleyviaduct.org.uk
- ENVIRONMENTS - e.g. test:www
- COMPOSE_PROJECT_NAME - e.g. fobv

The helper will then run a `wp search-replace` command for each of the colon separate environments as follows:

`wp search-replace https://[environment].$DOMAIN http://$COMPOSE_PROJECT_NAME`

Since the backup will have come from one of the test or the www environment there is some redundancy here but it keeps things simple and is harmless.

### _restore-plugin

### _restore-theme
