#!/usr/bin/env bash

set -e

case $1 in

  _restore)

    # Find the archive of the website's home folder.
    echo "Restoring wp-content folders"
    archive=$(find /backup -name "*.tar.gz")
    tar --extract --directory=/tmp --file=$archive
    wp_content=$(find /tmp -name wp-content)
    for DIR in plugins themes uploads
    do
      rm -rf /var/www/html/wp-content/$DIR
      mv $wp_content/$DIR /var/www/html/wp-content/$DIR
    done
    rm -rf /tmp/*

    echo "Search replace of site URL"
    IFS=':'
    read -a environments <<< "$ENVIRONMENTS"
    for environment in "${environments[@]}"
    do
      wp search-replace                                                        \
        https://$environment.$DOMAIN http://$COMPOSE_PROJECT_NAME
    done

    ;;

  *)
    wp $@
    ;;

esac
