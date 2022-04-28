#!/bin/bash
#
# MISP docker startup script

set -e

if [ -r /tmp/.firstboot.tmp ]; then
    echo "Container started for the fist time. Setup might time a few minutes. Please wait..."
    echo "(Details are logged in /tmp/install.log)"
    export DEBIAN_FRONTEND=noninteractive

    # If the user uses a mount point restore our files
    if [ ! -f /var/www/MISP/app/Config/config.php ]; then
        echo "Restoring MISP Config files..."
        cd /var/www/MISP/app/Config
        tar xzpf /tmp/MISPconfig.tgz
        rm /tmp/MISPconfig.tgz
    fi

    # echo "Configuring postfix"
    # if [ -z "$POSTFIX_RELAY_HOST" ]; then
    #         echo "POSTFIX_RELAY_HOST is not set, please configure Postfix manually later..."
    # else
    #         postconf -e "relayhost = $POSTFIX_RELAY"
    # fi

    # Fix timezone (adapt to your local zone)
    # if [ -z "$TIMEZONE" ]; then
    #         echo "TIMEZONE is not set, please configure the local time zone manually later..."
    # else
    #         echo "$TIMEZONE" > /etc/timezone
    #         dpkg-reconfigure -f noninteractive tzdata >>/tmp/install.log
    # fi

    echo "Checking Database"

    # Check MYSQL_HOST
    if [ -z "$MYSQL_HOST" ]; then
        echo "MYSQL_HOST is not set. Aborting."
        exit 1
    fi

    # Waiting for DB to be ready
    while ! mysqladmin ping -h"$MYSQL_HOST" --silent; do
        sleep 5
        echo "Waiting for database to be ready..."
    done

    # Set MYSQL_PASSWORD
    if [ -z "$MYSQL_PASSWORD" ]; then
        echo "MYSQL_PASSWORD is not set"
        exit 1
    fi

    export RESULT=`mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -e "use misp; show tables;" | grep admin_settings`
    if [ -n "$RESULT" ]; then
        echo 'Database Exists'
    else
        echo 'Initializing DB'
        mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D$MYSQL_DATABASE < /var/www/MISP/INSTALL/MYSQL.sql
        if [ $? -eq 0 ]; then
            echo "Imported /var/www/MISP/INSTALL/MYSQL.sql successfully"
        else
            echo "ERROR: Importing /var/www/MISP/INSTALL/MYSQL.sql failed:"
            echo $ret
        fi
    fi

    # Adding external config to MISP via config.php
    if [ -z $EXTERNAL_CONFIG ] || [ $EXTERNAL_CONFIG == "" ] || [ ! -f "$EXTERNAL_CONFIG" ]; then
            echo "INFO - Not using external config for MISP"
    else
        echo "INFO - Using external config file for MISP"
        cp -f $EXTERNAL_CONFIG /var/www/MISP/app/Config/config.external.php
        echo "include 'config.external.php';" >> config.php
        echo "" >> config.php
    fi

    # Adding external config to MISP via config.php
    if [ -z $EXTERNAL_BOOTSRAP ] || [ $EXTERNAL_BOOTSRAP == "" ] || [ ! -f "$EXTERNAL_BOOTSRAP" ]; then
            echo "INFO - Not using external bootstrap for MISP"
    else
        echo "INFO - Using external bootstrap file for MISP"
        cp -f $EXTERNAL_BOOTSRAP /var/www/MISP/app/Config/bootstrap.external.php
        echo "include 'bootstrap.external.php';" >> bootstrap.php
        echo "" >> bootstrap.php
    fi
    /var/www/MISP/app/Console/cake userInit -q

    # Generate the admin user PGP key
    echo "Creating admin GnuPG key"
    if [ -z "$MISP_ADMIN_EMAIL" -o -z "$MISP_ADMIN_PASSPHRASE" ]; then
        echo "No admin details provided, don't forget to generate the PGP key manually!"
    else
        echo "Generating admin PGP key ... (please be patient, we need some entropy)"
        cat >/tmp/gpg.tmp <<GPGEOF
%echo Generating a basic OpenPGP key
Key-Type: RSA
Key-Length: 2048
Name-Real: MISP Admin
Name-Email: $MISP_ADMIN_EMAIL
Expire-Date: 0
Passphrase: $MISP_ADMIN_PASSPHRASE
%commit
%echo Done
GPGEOF
    sudo -u www-data gpg --homedir /var/www/MISP/.gnupg --gen-key --batch /tmp/gpg.tmp >>/tmp/install.log
    rm -f /tmp/gpg.tmp
    sudo -u www-data gpg --homedir /var/www/MISP/.gnupg --export --armor $MISP_ADMIN_EMAIL > /var/www/MISP/app/webroot/gpg.asc
    fi
    export CAKE=/var/www/MISP/app/Console/cake
    $CAKE userInit -q
    $CAKE Admin setSetting "MISP.python_bin" "/var/www/MISP/venv/bin/python3"
    $CAKE Admin setSetting "MISP.redis_host" "${REDIS_HOST:=localhost}"
    $CAKE Admin setSetting "MISP.redis_port" "${REDIS_PORT:=6379}"
    $CAKE Admin setSetting "MISP.redis_password" "${REDIS_PASSWORD:=}"
    $CAKE Admin setSetting "Security.salt" $(openssl rand -base64 32|tr "/" "-")

    if [ -z "$MISP_MODULES_URL" ] || [ -z "$MISP_MODULES_PORT" ]; then
        echo "MISP Modules ENV Variables not set properly.  Skipping."
    else
        # Enrichment Services
        echo "Enabling MISP Modules Enrichment Plugins"
        $CAKE Admin setSetting "Plugin.Enrichment_services_enable" 1
        $CAKE Admin setSetting "Plugin.Enrichment_hover_enable" 1
        $CAKE Admin setSetting "Plugin.Enrichment_timeout" 300
        $CAKE Admin setSetting "Plugin.Enrichment_hover_timeout" 150
        $CAKE Admin setSetting "Plugin.Enrichment_services_url" $MISP_MODULES_URL
        $CAKE Admin setSetting "Plugin.Enrichment_services_port" $MISP_MODULES_PORT
        # Import Services
        echo "Enabling MISP Modules Import Plugins"
        $CAKE Admin setSetting "Plugin.Import_services_enable" 1
        $CAKE Admin setSetting "Plugin.Import_timeout" 300
        $CAKE Admin setSetting "Plugin.Import_services_url" $MISP_MODULES_URL
        $CAKE Admin setSetting "Plugin.Import_services_port" $MISP_MODULES_PORT
        # Export Services
        echo "Enabling MISP Modules Export Plugins"
        $CAKE Admin setSetting "Plugin.Export_services_enable" 1
        $CAKE Admin setSetting "Plugin.Export_timeout" 300
        $CAKE Admin setSetting "Plugin.Export_services_url" $MISP_MODULES_URL
        $CAKE Admin setSetting "Plugin.Export_services_port" $MISP_MODULES_PORT
    fi

    if [ ! -z "$ADMIN_PASS" ]; then
        echo "Setting Admin Password"
        $CAKE Password admin@admin.test "$ADMIN_PASS" -o
    fi
    if [ ! -z "$ADMIN_AUTH_KEY" ]; then
        echo "Setting Admin Auth Key"
        $CAKE Authkey admin@admin.test "$ADMIN_AUTH_KEY"
    fi

    # Loop through ENV vars and set individual settings via specially named vars
    for var in "${!SETTING_@}"; do
        string="${var/#SETTING_}"
        group="${string/%_*}"
        setting="${string#*_}"
        echo "Setting ${group}.${setting}"
        $CAKE Admin setSetting "${group}.${setting}" "${!var}" || true
    done

    $CAKE Live 1

    # Display tips
    cat <<__WELCOME__
Congratulations!
Your MISP docker has been successfully booted for the first time.
Don't forget:
- Reconfigure postfix to match your environment
- Change the MISP admin email address to $MISP_ADMIN_EMAIL
__WELCOME__
    rm -f /tmp/.firstboot.tmp
fi

chown www-data:www-data /var/www/MISP/app/Config/config.php*
echo "Starting MISP"
/var/www/MISP/app/Console/worker/start.sh
service shibd start
source /etc/apache2/envvars && exec /usr/sbin/apache2 -D FOREGROUND
