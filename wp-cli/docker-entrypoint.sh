#!/usr/bin/env bash

# Wrapper script to WP-CLI that provides several shortcut "helper scripts" as
# well as the native fuctionality of WP-CLI itself.

set -e

if [ "$1" = '_' ]
  then

    # I've been called with the single argument '_', which means "Show me the
    # available helpers so that I may select one of them."

    echo 'Helpers available'
    PS3='Helper? '
    select HELPER in                                                           \
      _create-admin-user                                                       \
      _correct_site_url                                                        \
      _export_post                                                             \
      _import_post                                                             \
      _install_importer                                                        \
      _remove-contact-form-recaptcha-integration                               \
      _restore-from-backup                                                     \
      _restore_media                                                           \
      _restore_plugin                                                          \
      _restore_theme                                                           \
      _exit
    do
      if [[ -n $HELPER ]]
        then
          set -- "$HELPER"
          break
        else
          echo 'Invalid selection, enter the number of a helper in the list'
      fi
    done

fi

case $1 in

  _create-admin-user)

    # Create an admin user for use within the container

    # It doesn't matter that the credentials are not secure since we're only
    # going to use this user on the developer desktop.
    php /wp-cli.phar                                                           \
      --allow-root                                                             \
      user create admin admin@localhost.localdomain                            \
      --role=administrator --user_pass=password

  ;;

  _correct_site_url)

    echo "Change the site's URL in the database to match the container URL"
    IFS=':'
    read -a environments <<< "$ENVIRONMENTS"
    for environment in "${environments[@]}"
    do
      echo                                                                     \
        "Replace https://$environment.$DOMAIN with http://$COMPOSE_PROJECT_NAME"
      php /wp-cli.phar --allow-root search-replace --report-changed-only       \
        https://$environment.$DOMAIN http://$COMPOSE_PROJECT_NAME
    done

  ;;

  _export_post)

    cd /posts
    read -p 'Post name: ' post_name

    # NOTE: The post list requires that the post is published
    php /wp-cli.phar export                                                    \
      --allow-root                                                             \
      --path=/var/www/html/                                                    \
      --post__in="$(                                                           \
          php /wp-cli.phar post list                                           \
            --allow-root                                                       \
            --path=/var/www/html/                                              \
            --name=$post_name                                                  \
            --format=ids                                                       \
        )"                                                                     \
      --filename_format=${post_name}.xml

    chown ${UID}:${GID} /posts/${post_name}.xml

  ;;

  _import_post)

    cd /posts
    read -p 'Post name: ' post_name

    php /wp-cli.phar import                                                    \
      --allow-root                                                             \
      --path=/var/www/html/                                                    \
      ${post_name}.xml                                                         \
      --authors=skip

    chown ${UID}:${GID} /posts/${post_name}.xml

  ;;

  _install_importer)

    php /wp-cli.phar                                                           \
      --allow-root                                                             \
      plugin install wordpress-importer --activate

  ;;

  _remove-contact-form-recaptcha-integration)

    # Remove Contact Form 7 integration with reCAPTCHA

    php /wp-cli.phar option patch delete wpcf7 recaptcha

  ;;

  _restore_media)

    # Find the archive file of website's home folder
    archive=$(find /backup -name "*.tar.gz")
    echo "Archive file found at $archive"

    if [[ ! -e /var/www/html/wp-content/uploads ]]
      then
        mkdir -p /var/www/html/wp-content/uploads
    fi

    tar                                                                        \
      --extract                                                                \
      --file=$archive                                                          \
      --directory=/var/www/html/wp-content/uploads                             \
      --transform="s~.*wp-content/uploads/~~"                                  \
      --wildcards                                                              \
      "**wp-content/uploads/**"

    chown -R www-data:www-data /var/www/html/wp-content/uploads/*

  ;;

  _restore_plugin)

    # Find the archive file of website's home folder
    archive=$(find /backup -name "*.tar.gz")
    echo "Archive file found at $archive"

    for path in                                                                \
      $(tar --list --file=$archive --wildcards "**wp-content/plugins/")
    do
      regex='wp-content/plugins/([a-z0-9-]+)/$'
      if [[ $path =~ $regex ]]
        then
          if [[ -z "$plugins" ]]
            then
              plugins=${BASH_REMATCH[1]}
            else
              plugins="$plugins ${BASH_REMATCH[1]}"
          fi
      fi
    done

    echo 'Plugins available'
    PS3='Plugin to restore? '
    select plugin in $plugins
    do
      if [[ -n $plugin ]]
        then
          set -- "$plugin"
          break
        else
          echo 'Invalid selection, enter the number of a plugin in the list'
      fi
    done

    tar                                                                        \
      --extract                                                                \
      --file=$archive                                                          \
      --directory=/var/www/html/wp-content/plugins                             \
      --transform="s~.*wp-content/themes/$plugin/~$plugin/~"                   \
      --wildcards                                                              \
      "**wp-content/plugins/$plugin/"

  ;;

  _restore_theme)

    # Find the archive file of website's home folder
    archive=$(find /backup -name "*.tar.gz")
    echo "Archive file found at $archive"

    for path in                                                                \
      $(tar --list --file=$archive --wildcards "**wp-content/themes/")
    do
      regex='wp-content/themes/([a-z0-9-]+)/$'
      if [[ $path =~ $regex ]]
        then
          if [[ -z "$themes" ]]
            then
              themes=${BASH_REMATCH[1]}
            else
              themes="$themes ${BASH_REMATCH[1]}"
          fi
      fi
    done

    echo 'Themes available'
    PS3='Theme to restore? '
    select theme in $themes
    do
      if [[ -n $theme ]]
        then
          set -- "$theme"
          break
        else
          echo 'Invalid selection, enter the number of a theme in the list'
      fi
    done

    tar                                                                        \
      --extract                                                                \
      --file=$archive                                                          \
      --directory=/var/www/html/wp-content/themes                              \
      --transform="s~.*wp-content/themes/$theme/~$theme/~"                     \
      --wildcards                                                              \
      "**wp-content/themes/$theme/"

  ;;

  _restore-from-backup)

    echo 'Restoring the WordPress installation from the backup to the container'

    # Find the archive file of website's home folder
    archive=$(find /backup -name "*.tar.gz")
    echo "Archive file found at $archive"

    wp_settings=$(tar --list --file=$archive --wildcards "*/wp-settings.php")
    # Extract all the forward slashes from the full path of the wp_config file
    slashes="${wp_settings//[^\/]}"
    # Count the components to strip from file names on extraction
    components="${#slashes}"

    echo $components

    # If I have used a bacula restore to create the archive, then it will
    # contain the wp-config.php file. If I have used `scp -rp` instead, then it
    # won't because of file permissions on the live server. Look to see if this
    # archive contains the wp-config.php file. Using `grep` rather than a tar
    # wildcard pattern avoids a bash failure status that halts execution.
    if [ $(tar --list --file=$archive | grep -F 'wp-config.php') ]
      then

        wp_config=$(tar --list --file=$archive --wildcards "*/wp-config.php")
        echo "wp-config.php found at $wp_config"
        # Extract from the archive to the WordPress home in the container
        tar                                                                    \
          --extract                                                            \
          --file=$archive                                                      \
          --directory=/var/www/html                                            \
          --strip-components=$components                                       \
          --exclude=$wp_config

      else

        echo 'No wp-config.php file found in the archive'
        tar                                                                    \
          --extract                                                            \
          --file=$archive                                                      \
          --directory=/var/www/html                                            \
          --strip-components=$components

    fi

    echo 'Extract from the archive completed'

  ;;

  _exit)

  ;;

  *)

    php /wp-cli.phar --allow-root $@

  ;;

esac
