#!/usr/bin/sh

if [ ! -f /etc/bareos-webui/bareos-webui-config.control ]; then
  # Populate host volume map with package defaults from docker build steps:
  tar xfz /bareos-webui.tgz --backup=simple --suffix=.before-webui-config --strip 1 --directory /etc/bareos-webui
  # if BAREOS_DIR_NAME is unset, set from directors bareos-dir.conf via shared /etc/bareos, if found.
  # Otherwise default to "bareos-dir"
  if [ -z "${BAREOS_DIR_NAME}" ] && [ -f /etc/bareos/bareos-dir.d/director/bareos-dir.conf ]; then
    # Use Director's config "Name = bareos-dir" found in:
    # /etc/bareos/bareos-dir.d/director/bareos-dir.conf
    # TODO set BAREOS_DIR_NAME from directors default bareos-dir.conf config if possible
    echo
  fi

  if [ -z "${BAREOS_DIR_NAME}" ]; then
    BAREOS_DIR_NAME="bareos-dir"
  fi

  # Set this WebUI's director address
  sed -i 's#diraddress = .*#diraddress = '\""${BAREOS_DIR_NAME}"\"'#' \
    /etc/bareos-webui/directors.ini
  # Modify default "[localhost-dir]" to our directors name, as localhost-dir is confusing,
  # especially in the case of a remote director: translates to Director selection on home-page.
  sed -i 's#localhost-dir#'"${BAREOS_DIR_NAME}"'#' \
    /etc/bareos-webui/directors.ini

  # Enable PHP-FPM daemon /status page on default listen address:
  sed -i 's#;pm.status_path = .*#pm.status_path = \/status#' \
    /etc/php8/fpm/php-fpm.d/www.conf

  # Control file
  touch /etc/bareos-webui/bareos-webui-config.control
fi

# https://docs.bareos.org/IntroductionAndTutorial/BareosWebui.html
# https://www.zend.com/blog/apache-phpfpm-modphp
# Bareos-webui apache2 server requries PHP-FPM and mod-rewrite and mod-fcgid enabled
# See: https://httpd.apache.org/mod_fcgid/ & https://httpd.apache.org/mod_fcgid/mod/mod_fcgid.html
# Also openSuse specific: https://en.opensuse.org/SDB:Apache_FastCGI_and_PHP-FPM_configuration
# `apachectl -M` to see enabled Apache modules
# We must also start invoke a PHP-FPM servcie:
# `rpm -ql php8-fpm` includes: '/usr/lib/systemd/system/php-fpm.service' with an ExecStart akin to the following:
# - /etc/php8/fpm/php-fpm.conf
# - /etc/php8/fpm/php.ini
# - /etc/php8/fpm/php-fpm.d/*.conf (we have a pre-installed: /etc/php8/fpm/php-fpm.d/www.conf)
# Notable configurations in www.conf:
# - ;listen.allowed_clients = 127.0.0.1
# - ;pm.status_path = /status
# - ;pm.status_listen = 127.0.0.1:9001
/usr/sbin/php-fpm --fpm-config /etc/php8/fpm/php-fpm.conf

# Run Dockerfile CMD
exec "$@"
