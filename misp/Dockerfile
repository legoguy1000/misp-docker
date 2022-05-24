FROM ubuntu:focal

#User Input
ARG MISP_VERSION=2.4.158
ARG MISP_TAG=v${MISP_VERSION}

# Install core components
ENV DEBIAN_FRONTEND noninteractive
ENV LANG en_US.UTF-8
ENV PATH_TO_MISP /var/www/MISP

# Apache and PHP 7.4 and install MySQL PDO extension
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    apache2 apache2-doc apache2-utils libapache2-mod-shib libapache2-mod-php php php-dev php-cli php-json php-zip php-intl php-apcu \
    php-mysql php-redis php-gnupg php-xml php-mbstring php-gd php-pear php-opcache php-curl php-readline pkg-config php-bcmath libbson-1.0 libmongoc-1.0-0 \
    python3 python3-dev python3-pip python3-virtualenv libjpeg-dev libxml2-dev libxslt1-dev zlib1g-dev libfuzzy-dev cron logrotate \
    gcc make software-properties-common mariadb-client curl git gnupg-agent openssl zip locales supervisor \
    libpoppler97 libpoppler-dev libpoppler-cpp-dev g++ && apt-get clean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && \
    a2dismod status && a2dissite 000-default && locale-gen en_US.UTF-8 && phpenmod redis && \
    sed -i \
        -e "s/max_execution_time = 30/max_execution_time = 300/" \
        -e "s/memory_limit = 128M/memory_limit = 2048M/" \
        -e "s/upload_max_filesize = 2M/upload_max_filesize = 50M/" \
        -e "s/post_max_size = 8M/post_max_size = 50M/" \
        -e "s/session.use_strict_mode = 0/session.use_strict_mode = 1/" \
        -e "s/session.sid_length = 26/session.sid_length = 32/" \
        /etc/php/7.4/apache2/php.ini

WORKDIR /var/www
RUN git clone https://github.com/MISP/MISP.git
WORKDIR ${PATH_TO_MISP}
RUN git checkout tags/${MISP_TAG} && \
    git config core.filemode false && \
    git submodule update --init --recursive && \
    git submodule foreach --recursive git config core.filemode false && \
    virtualenv -p python3 ${PATH_TO_MISP}/venv && \
    ${PATH_TO_MISP}/venv/bin/pip3 install \
                #  git+https://github.com/STIXProject/python-stix.git \
                #  git+https://github.com/CybOXProject/python-cybox.git \
                #  git+https://github.com/CybOXProject/mixbox.git \
                #  git+https://github.com/MAECProject/python-maec.git \
                 git+https://github.com/kbandla/pydeep.git \
                 ${PATH_TO_MISP}/app/files/scripts/misp-stix \
                 ${PATH_TO_MISP}/app/files/scripts/python-stix \
                 ${PATH_TO_MISP}/app/files/scripts/python-maec \
                 ${PATH_TO_MISP}/app/files/scripts/mixbox \
                 ${PATH_TO_MISP}/app/files/scripts/python-cybox \
                 ${PATH_TO_MISP}/app/files/scripts/cti-python-stix2 \
                 ${PATH_TO_MISP}/PyMISP \
                 setuptools plyara python-magic lxml lief redis pyzmq mail-parser ssdeep && \
    git submodule init && git submodule update

WORKDIR /tmp
RUN curl -o ssdeep-2.14.1.tar.gz -L https://github.com/ssdeep-project/ssdeep/releases/download/release-2.14.1/ssdeep-2.14.1.tar.gz && \
    tar zxvf ssdeep-2.14.1.tar.gz
WORKDIR  /tmp/ssdeep-2.14.1
RUN ./configure && make && make install && pecl install ssdeep && \
    echo 'extension=ssdeep.so' | tee -a /etc/php/7.4/apache2/php.ini /etc/php/7.4/cli/php.ini && phpenmod ssdeep && rm -rf /tmp/ssdeep* /tmp/pear

WORKDIR ${PATH_TO_MISP}/app

# FIX COMPOSER
RUN curl --fail --location -o composer-setup.php https://getcomposer.org/installer && php composer-setup.php && php -r "unlink('composer-setup.php');" && \
    php composer.phar update &&  php composer.phar config vendor-dir Vendor &&  php composer.phar install --ignore-platform-reqs --no-dev && \
    cp -fa ${PATH_TO_MISP}/INSTALL/setup/config.php ${PATH_TO_MISP}/app/Plugin/CakeResque/Config/config.php && \
    cp ${PATH_TO_MISP}/INSTALL/misp.logrotate /etc/logrotate.d/misp

# Apache Setup
RUN cp ${PATH_TO_MISP}/INSTALL/apache.misp.ubuntu /etc/apache2/sites-available/misp.conf && \
    a2dissite 000-default default-ssl && a2ensite misp && a2enmod rewrite headers ssl shib

# MISP base configuration
RUN cp -a ${PATH_TO_MISP}/app/Config/bootstrap.default.php ${PATH_TO_MISP}/app/Config/bootstrap.php && \
    cp -a ${PATH_TO_MISP}/app/Config/database.default.php ${PATH_TO_MISP}/app/Config/database.php && \
    cp -a ${PATH_TO_MISP}/app/Config/core.default.php ${PATH_TO_MISP}/app/Config/core.php && \
    cp -a ${PATH_TO_MISP}/app/Config/config.default.php ${PATH_TO_MISP}/app/Config/config.php

COPY files/database.php ${PATH_TO_MISP}/app/Config/database.php
# COPY config/config.php ${PATH_TO_MISP}/app/Config/config.php
# COPY config/cake_config.php ${PATH_TO_MISP}/app/Plugin/CakeResque/Config/config.php

# Replace the default salt
RUN sed -i "s|\"sudo -u \"\s*\.\s*\$this->_runtime\['user'\]|\"\"|g" ${PATH_TO_MISP}/app/Plugin/CakeResque/Console/Command/CakeResqueShell.php && \
    sed -i -e "s|'host'\s*=>\s*'[a-zA-Z0-9._-]*',|'host' => env('REDIS_HOST','localhost'),|g" \
           -e "s|'port'\s*=>\s*6379,|'port' => env('REDIS_PORT',null),|g"  \
           -e "s|'password'\s*=>\s*null|'password' => env('REDIS_PASSWORD',null)|g" ${PATH_TO_MISP}/app/Plugin/CakeResque/Config/config.php && \
    sed -i "s/Listen 80/Listen 8080/g" /etc/apache2/ports.conf && \
    sed -i "s/Listen 443/Listen 8443/g" /etc/apache2/ports.conf && \
    sed -i "s/80/8080/g" /etc/apache2/sites-available/misp.conf


# Install templates & stuff
WORKDIR ${PATH_TO_MISP}/app/files
RUN rm -rf misp-objects && git clone https://github.com/MISP/misp-objects.git && \
    rm -rf misp-galaxy && git clone https://github.com/MISP/misp-galaxy.git && \
    rm -rf warninglists && git clone https://github.com/MISP/misp-warninglists.git ./warninglists && \
    rm -rf taxonomies && git clone https://github.com/MISP/misp-taxonomies.git ./taxonomies

# Add run script
# Trigger to perform first boot operations
COPY files/run_misp.sh /run_misp.sh
RUN chmod 0755 /run_misp.sh && touch /tmp/.firstboot.tmp && chown -R www-data:www-data /tmp/.firstboot.tmp /var/log/apache2 /var/run/apache2

# Make a backup of /var/www/MISP to restore it to the local moint point at first boot
WORKDIR ${PATH_TO_MISP}/app/Config
RUN tar czpf /tmp/MISPconfig.tgz .

RUN chown -R www-data:www-data ${PATH_TO_MISP} /tmp/MISPconfig.tgz && chmod -R 750 ${PATH_TO_MISP} /tmp/MISPconfig.tgz && \
    chmod -R g+ws ${PATH_TO_MISP}/app/tmp && chmod -R g+ws ${PATH_TO_MISP}/app/files && chmod -R g+ws ${PATH_TO_MISP}/app/files/scripts/tmp && \    
    mkdir -p /run/shibboleth && chown -R www-data:www-data /run/shibboleth /var/log/shibboleth /var/run/shibboleth && \
    chmod -R 775 /run/shibboleth /var/log/shibboleth /var/run/shibboleth

HEALTHCHECK --timeout=15s CMD curl http://localhost:8080/
VOLUME ${PATH_TO_MISP}/app/Config
EXPOSE 8080
USER www-data
ENTRYPOINT ["/run_misp.sh"]
