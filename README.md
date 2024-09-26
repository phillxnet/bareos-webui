# Bareos WebUI

Follows Bareos's own install instructions as closely as possible: given container limitations.
Initially uses only Bareos distributed community packages [Bareos Community Repository](https://download.bareos.org/current) `Current` variant.

Intended future capability, upon instantiation, is to use the [Official Bareos Subscription Repository](https://download.bareos.com/bareos/release/),
if non-empty subscription credentials are passed by environmental variables.

See: [Decide about the Bareos release to use](https://docs.bareos.org/IntroductionAndTutorial/InstallingBareos.html#decide-about-the-bareos-release-to-use)

Based on opensuse/leap:15.6 as per BareOS instructions:
[SUSE Linux Enterprise Server (SLES), openSUSE](https://docs.bareos.org/IntroductionAndTutorial/InstallingBareos.html#install-on-suse-based-linux-distributions)

Inspired & informed by the many years of Bareos container maintenance done by Marc Benslahdine https://github.com/barcus/bareos, and contributors.

## Environmental Variables

- BAREOS_DIR_NAME: If unset defaults to "bareos-dir".
 Tally with Director's 'Name' in /etc/bareos/bareos-dir.d/director/bareos-dir.conf

The following must match with an associated Director's config in /etc/bareos/bareos-dir.d/console/admin.conf
- BAREOS_WEBUI_PASSWORD: Must be set.

## Local Build
- -t tag <name>
- . indicates from-current directory

```shell
docker build -t bareos-webui .
```

## Run WebUI container

The following assumes:
- The Director (named "bareos-dir") is accessible via docker network `bareosnet`.
See: https://docs.docker.com/engine/network
```shell
docker run --name bareos-webui\
 -e BAREOS_DIR_NAME='bareos-dir'\
 -p 9100:80\
 --network=bareosnet bareos-webui
# and to remove
docker remove bareos-webui
```

## Interactive shell

```
docker exec -it bareos-webui sh
```

## Website access

Via an example IP of the container:

> http://172.20.0.6/bareos-webui/

N.B. we add the following in docker build:
```shell
DirectoryIndex index.php
<FilesMatch "\.php$">
    SetHandler "proxy:fcgi://127.0.0.1:9000/"
    #CGIPassAuth on
</FilesMatch>
```
to /etc/apache2/conf.d/mod_fcgid.conf

## BareOS rpm package scriptlet actions

### bareos-webui
```shell
# Installs the following apache config file containing:
# `Alias /bareos-webui  /usr/share/bareos-webui/public`
/etc/apache2/conf.d/bareos-webui.conf
# WebUI files:
/usr/share/bareos-webui
```
There are also the following files intended to pre-configure/example-config a local director.
```shell
/etc/bareos/bareos-dir.d/console/admin.conf.example
/etc/bareos/bareos-dir.d/profile/webui-admin.conf
/etc/bareos/bareos-dir.d/profile/webui-limited.conf.example
/etc/bareos/bareos-dir.d/profile/webui-readonly.conf
```
The same author bareos-dir docker image already pre-installs:
- console: admin.conf (via the example); edited with directors BAREOS_WEBUI_PASSWORD.
- profile: webui-admin.conf (used as-is).
This bareos-webui docker image, as it runs non bareos:bareos user:group, is not intended to share volumes.

### system-user-wwwrun
A dependency of Apache2
```shell
/usr/sbin/groupadd -r www
/usr/sbin/useradd -r -c WWW daemon apache -d /var/lib/wwwrun -U wwwrun -s /usr/sbin/nologin
/usr/sbin/usermod -a -G www wwwrun
```
