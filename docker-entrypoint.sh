#!/usr/bin/env bash

set -e

if [ "$1" = "_" ]; then

  echo "Helpers available"
  PS3='Helper?'
  select HELPER in                                                             \
    _create-admin-user                                                         \
    _remove-contact-form-recaptcha-integration                                 \
    _restore-from-backup
  do
    if [[ -n $HELPER ]]; then
      set -- "$HELPER"
      break
    else
      echo "Invalid selection, enter number for the desired helper in the list"
    fi
  done

fi

case $1 in

  _create-admin-user)

    # Create an admin user for use within the container

    # It doesn't matter that the credentials are not secure since we're only
    # going to use this user on the developer desktop.
    wp user create admin admin@localhost.localdomain                           \
      --role=administrator --user_pass=password

    ;;

  _remove-contact-form-recaptcha-integration)

    # Remove Contact Form 7 integration with reCAPTCHA

    wp option patch delete wpcf7 recaptcha

    ;;

  _restore-from-backup)

    echo "Restoring the WordPress installation from the backup to the container"
    # Find the archive file of website's home folder
    archive=$(find /backup -name "*.tar.gz")
    echo "Archive file found at $archive"
    # Get the full path of the wp_config file from the archive
    wp_config=$(tar --list --file=$archive --wildcards "*/wp-config.php")
    echo "wp-config.php found at $wp_config"
    # Extract all the forward slashes from the full path of the wp_config file
    slashes="${wp_config//[^\/]}"
    # Count the components to strip from file names on extraction
    components="${#slashes}"
    # Extract from the archive to the WordPress home in the container
    tar                                                                        \
      --extract                                                                \
      --file=$archive                                                          \
      --directory=/var/www/html                                                \
      --strip-components=$components                                           \
      --exclude=$wp_config
    echo "Extract from the archive completed"

    echo                                                                       \
      "Change this site's URLs in the WordPress database to match the container"
    IFS=':'
    read -a environments <<< "$ENVIRONMENTS"
    for environment in "${environments[@]}"
    do
      echo                                                                     \
        "Replace https://$environment.$DOMAIN with http://$COMPOSE_PROJECT_NAME"
      wp search-replace --report-changed-only                                  \
        https://$environment.$DOMAIN http://$COMPOSE_PROJECT_NAME
    done

    ;;

  *)

    wp $@
    ;;

esac
