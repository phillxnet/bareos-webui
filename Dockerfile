# Rockstor Bareos server set
FROM opensuse/leap:15.6

# For our setup we explicitly use container's root user at '/':
USER root
WORKDIR /

# https://specs.opencontainers.org/image-spec/annotations/
LABEL maintainer="The Rockstor Project <https://rockstor.com>"
LABEL org.opencontainers.image.authors="The Rockstor Project <https://rockstor.com>"
LABEL org.opencontainers.image.description="Bareos WebUI - deploys packages from https://download.bareos.org/"

# We only know if we are COMMUNIT or SUBSCRIPTION at run-time via env vars.
# - apache2-utils: /usr/sbin/apache2ctl (to invoke apache2 without systemd)
# - apache2-event: provides, via the alternative system, an mpm_event (non mpm_prefork) apache variant.
# -- recommendation when using FastCGI / PHP-FPM: with FastCGI:
# "... the FastCGI pool determines how to handle incoming requests, and php-fpm spawns new workers... "
# Reference: https://www.zend.com/blog/apache-phpfpm-modphp
# And: https://en.opensuse.org/SDB:Apache_FastCGI_and_PHP-FPM_configuration
RUN zypper --non-interactive install tar gzip wget iputils strace apache2-event apache2-mod_fcgid apache2-utils procps less nano

# Create bareos group & user within container with set gid & uid.
# Docker host and docker container share uid & gid.
# Pre-empting the bareos packages' installer doing the same, as we need to known gid & uid for host volume permissions.
# We leave bareos home-dir to be created by the package install scriptlets.
#RUN groupadd --system --gid 105 bareos
#RUN useradd --system --uid 105 --comment "bareos" --home-dir /var/lib/bareos -g bareos --shell /bin/false bareos

RUN <<EOF
# https://docs.bareos.org/IntroductionAndTutorial/InstallingBareos.html#install-on-suse-based-linux-distributions

# ADD REPOS (COMMUNITY OR SUBSCRIPTION)
# https://docs.bareos.org/IntroductionAndTutorial/WhatIsBareos.html#bareos-binary-release-policy
# - Empty/Undefined BAREOS_SUB_USER & BAREOS_SUB_PASS = COMMUNITY 'current' repo.
# -- Community current repo: https://download.bareos.org/current
# -- wget https://download.bareos.org/current/SUSE_15/add_bareos_repositories.sh
# - BAREOS_SUB_USER & BAREOS_SUB_PASS = Subscription rep credentials
# -- Subscription repo: https://download.bareos.com/bareos/release/
# User + Pass entered in the following retrieves the script pre-edited:
# wget https://download.bareos.com/bareos/release/23/SUSE_15/add_bareos_repositories.sh
# or
# wget https://download.bareos.com/bareos/release/23/SUSE_15/add_bareos_repositories_template.sh
# sed edit using BAREOS_SUB_USER & BAREOS_SUB_PASS
if [ ! -f  /etc/bareos-webui/bareos-webui-install.control ]; then
  # Retrieve and Run Bareos's official repository config script
  wget https://download.bareos.org/current/SUSE_15/add_bareos_repositories.sh
  sh ./add_bareos_repositories.sh
  zypper --non-interactive --gpg-auto-import-keys refresh
  # WebUI apache2 + php8 service
  zypper --non-interactive install bareos-webui
  # Control file
  touch /etc/bareos-webui/bareos-webui-install.control
fi
EOF

# https://en.opensuse.org/SDB:Apache_FastCGI_and_PHP-FPM_configuration
RUN sed -i 's/<\/IfModule>/#<\/IfModule>/' /etc/apache2/conf.d/mod_fcgid.conf
RUN <<EOF2 cat >> /etc/apache2/conf.d/mod_fcgid.conf
DirectoryIndex index.php
<FilesMatch "\.php$">
    SetHandler "proxy:fcgi://127.0.0.1:9000/"
    #CGIPassAuth on
</FilesMatch>
</IfModule>
EOF2
RUN sed -i 's/APACHE_MPM=""/APACHE_MPM="event"/' /etc/sysconfig/apache2

# https://httpd.apache.org/docs/2.4/mod/mpm_common.html#maxrequestworkers
# To address: "AH00513: WARNING: MaxRequestWorkers of 256 is not an integer multiple of ThreadsPerChild of 25..."
# /etc/apache2/server-tuning.conf
# see also: /etc/sysconfig/apache2
RUN sed -i 's/MaxRequestWorkers         256/MaxRequestWorkers         50/' /etc/apache2/server-tuning.conf
RUN sed -i 's/StartServers .*/StartServers         1/' /etc/apache2/server-tuning.conf
# Set Global `ServerName localhost`, avoids:
# "AH00558: httpd-event: Could not reliably determine the server's fully qualified domain name"
RUN sed -i '/^Alias .*/a ServerName localhost' /etc/apache2/conf.d/bareos-webui.conf

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
# /usr/sbin/php-fpm --fpm-config /etc/php8/fpm/php-fpm.conf

# Install pre-compiled x86_64-linux glibc binary of multirun from GitHub Release.
# https://github.com/nicolas-van/multirun
RUN wget -c https://github.com/nicolas-van/multirun/releases/download/1.1.3/multirun-x86_64-linux-gnu-1.1.3.tar.gz -O - | tar -xz
RUN mv multirun /usr/local/sbin

# Stash default package config: ready to populare host volume mapping
# https://docs.bareos.org/Configuration/CustomizingTheConfiguration.html#subdirectory-configuration-scheme
RUN ls -la /etc/bareos-webui > /etc/bareos-webui/bareos-webui-default-permissions.txt
RUN tar czf bareos-webui.tgz /etc/bareos-webui

# Config
VOLUME /etc/bareos-webui

# 'WebUI' interface port: to be mapped to e.g.: 9100
EXPOSE 80
# PHP-FPM service, via /status
# EXPOSE 9001

COPY docker-entrypoint.sh /usr/local/sbin/docker-entrypoint.sh
RUN chmod u+x /usr/local/sbin/docker-entrypoint.sh

# See README.md 'Host User configuration' section.
# The Bareos file daemon differes from all other bareos services by not running bareos:bareos.
# Established from package defaults as per /usr/lib/bareos/scripts/bareos-config-lib.sh
# USER root:bareos

# As per system-user-wwwrun pkg scriptlet config re:
# User:Group wwwrun:www
# See: /usr/lib/systemd/system/apache2.service
WORKDIR /var/lib/wwwrun

ENTRYPOINT ["docker-entrypoint.sh"]
# CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
# https://docs.docker.com/engine/containers/multi-service_container/
# https://medium.com/@keska.damian/meet-the-supervisord-alternative-multirun-6b3a259805e
# https://github.com/nicolas-van/multirun
# https://nicolas-van.github.io/multirun/
# /usr/sbin/php-fpm --fpm-config /etc/php8/fpm/php-fpm.conf
# /usr/sbin/start_apache2 -DFOREGROUND -k start
# CMD ["/usr/sbin/start_apache2", "-DFOREGROUND", "-k", "start"]
CMD ["multirun", "/usr/sbin/php-fpm --nodaemonize --fpm-config /etc/php8/fpm/php-fpm.conf", "/usr/sbin/start_apache2 -DFOREGROUND -k start"]