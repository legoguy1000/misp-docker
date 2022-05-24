FROM python:3.10-buster AS build

ENV DEBIAN_FRONTEND noninteractive
ENV WORKDIR="/usr/local/src/misp_modules"
ENV VENV_DIR="/misp_modules"
ARG MISP_MODULES_VERSION
ARG MISP_MODULES_TAG=v${MISP_MODULES_VERSION}
ARG MAXMIND_API_KEY

# Install Packages for build
RUN set -eu && mkdir -p ${WORKDIR} ${VENV_DIR} && apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    git libpq5 libjpeg-dev tesseract-ocr libpoppler-cpp-dev imagemagick virtualenv libopencv-dev \
    zbar-tools libzbar0 libzbar-dev libfuzzy-dev curl && \
    apt-get -y autoremove && apt-get -y clean && rm -rf /var/lib/apt/lists/*

# Create MISP Modules
RUN set -eu && git clone https://github.com/MISP/misp-modules.git ${WORKDIR} && python -m pip install --no-cache-dir --upgrade pip virtualenv && virtualenv -p python3 ${VENV_DIR}/venv
WORKDIR ${WORKDIR}
RUN     git checkout tags/${MISP_MODULES_TAG} && ${VENV_DIR}/venv/bin/pip3 install -I -r REQUIREMENTS --no-cache-dir && \
        ${VENV_DIR}/venv/bin/pip3 install . --no-cache-dir && \ 
        ${VENV_DIR}/venv/bin/pip3 install git+https://github.com/abenassi/Google-Search-API socialscan dnsdb2 censys pyfaup && \
        curl -L -o /tmp/GeoLite2-ASN.tar.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-ASN&license_key=${MAXMIND_API_KEY}&suffix=tar.gz"  && \
        curl -L -o /tmp/GeoLite2-City.tar.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${MAXMIND_API_KEY}&suffix=tar.gz" && \
        curl -L -o /tmp/GeoLite2-Country.tar.gz "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${MAXMIND_API_KEY}&suffix=tar.gz" && \
        mkdir -p /tmp/geoip && \
        tar -ztf /tmp/GeoLite2-ASN.tar.gz | grep mmdb | xargs -I X tar -Ozxf /tmp/GeoLite2-ASN.tar.gz X >> /tmp/geoip/GeoLite2-ASN.mmdb && \
        tar -ztf /tmp/GeoLite2-City.tar.gz | grep mmdb | xargs -I X tar -Ozxf /tmp/GeoLite2-City.tar.gz X >> /tmp/geoip/GeoLite2-City.mmdb && \
        tar -ztf /tmp/GeoLite2-Country.tar.gz | grep mmdb | xargs -I X tar -Ozxf /tmp/GeoLite2-Country.tar.gz X >> /tmp/geoip/GeoLite2-Country.mmdb


#########################################
# Start Final Docker Image
#
FROM python:3.10-slim-buster AS final

ENV DEBIAN_FRONTEND noninteractive
ENV VENV_DIR="/misp_modules"

# Copy all builded files from build stage
COPY --from=build ${VENV_DIR} ${VENV_DIR}
COPY --from=build /tmp/geoip ${VENV_DIR}/geoip

# Entrypoint
COPY files/entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

# Add Healthcheck Config
COPY files/healthcheck.sh /healthcheck.sh
HEALTHCHECK --interval=1m --timeout=45s --retries=3 CMD ["/healthcheck.sh"]

# Install Packages to run it
RUN set -eu && apt-get update && apt-get install -y --no-install-recommends curl libpq5 tesseract-ocr libpoppler-cpp-dev imagemagick \
    zbar-tools libzbar0 libgl1-mesa-glx && apt-get -y autoremove && apt-get -y clean && rm -rf /var/lib/apt/lists/* && \
    chown -R nobody ${VENV_DIR} /entrypoint.sh /healthcheck.sh && chmod +x /entrypoint.sh /healthcheck.sh


# Change Workdir
WORKDIR ${VENV_DIR}

# Change from root to www-data
USER nobody

# Expose Port
EXPOSE 6666

# Shortterm ARG Variables:
ARG VENDOR="MISP" \
    COMPONENT="misp-modules" \
    BUILD_DATE \
    GIT_REPO="https://github.com/MISP/misp-modules" \
    VCS_REF \
    RELEASE_DATE \
    NAME="MISP-dockerized-misp-modules" \
    DESCRIPTION="This docker container contains MISP modules in an Debian Container." \
    DOCUMENTATION="https://misp.github.io/misp-modules/" \
    AUTHOR="MISP" \
    LICENSE="BSD-3-Clause"

# Longterm Environment Variables
ENV BUILD_DATE=${BUILD_DATE} \
    NAME=${NAME} \
    PATH=$PATH:${VENV_DIR}/venv/bin

# Labels
LABEL   org.label-schema.build-date="${BUILD_DATE}" \
        org.label-schema.name="${NAME}" \
        org.label-schema.description="${DESCRIPTION}" \
        org.label-schema.vcs-ref="${VCS_REF}" \
        org.label-schema.vcs-url="${GIT_REPO}" \
        org.label-schema.url="${GIT_REPO}" \
        org.label-schema.vendor="${VENDOR}" \
        org.label-schema.version="${VERSION}" \
        org.label-schema.usage="${DOCUMENTATION}" \
        org.label-schema.schema-version="1.0.0-rc1" \
        org.opencontainers.image.created="${BUILD_DATE}" \
        org.opencontainers.image.url="${GIT_REPO}" \
        org.opencontainers.image.source="${GIT_REPO}" \
        org.opencontainers.image.version="${VERSION}" \
        org.opencontainers.image.revision="${VCS_REF}" \
        org.opencontainers.image.vendor="${VENDOR}" \
        org.opencontainers.image.title="${NAME}" \
        org.opencontainers.image.description="${DESCRIPTION}" \
        org.opencontainers.image.documentation="${DOCUMENTATION}" \
        org.opencontainers.image.authors="${AUTHOR}" \
        org.opencontainers.image.licenses="${LICENSE}"
