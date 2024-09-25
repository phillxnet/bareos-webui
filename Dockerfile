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
RUN zypper --non-interactive install tar gzip wget iputils strace apache2-utils procps

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

# Stash default package config: ready to populare host volume mapping
# https://docs.bareos.org/Configuration/CustomizingTheConfiguration.html#subdirectory-configuration-scheme
RUN ls -la /etc/bareos-webui > /etc/bareos-webui/bareos-webui-default-permissions.txt
RUN tar czf bareos-webui.tgz /etc/bareos-webui

# Config
VOLUME /etc/bareos-webui

# 'WebUI' interface port.
EXPOSE 9100

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
CMD ["/usr/sbin/start_apache2", "-DFOREGROUND", "-k", "start"]