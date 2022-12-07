# Not using a cli image from wordpress on Docker Hub as it is based on BusyBox
# and I need more shell command capability than that provides.

FROM debian:bullseye

RUN                                                                            \
  apt-get update                                                            && \
  apt-get --no-install-recommends --yes install                                \
    ca-certificates                                                            \
    less                                                                       \
    php                                                                        \
    php-mysql                                                                  \
    php-xml                                                                    \
    wget                                                                    && \
  wget --directory-prefix=/                                                    \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["--help"]

WORKDIR /var/www/html
