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

# Run Dockerfile CMD
exec "$@"
