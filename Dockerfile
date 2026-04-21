#
# Basic Parameters
#
ARG FIPS=""
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG PRIVATE_REGISTRY
ARG BASE_VER_PFX=""
ARG ARCH="x86_64"
ARG OS="linux"
ARG VER="24.04"
ARG PKG="samba"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base"
ARG BASE_VER="${VER}"
ARG BASE_VER_PFX="${BASE_VER_PFX}"
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}${FIPS}:${BASE_VER_PFX}${BASE_VER}"

FROM "${BASE_IMG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG PKG
ARG APP_UID="1999"
ARG APP_USER="samba"
ARG APP_GID="${APP_UID}"
ARG APP_GROUP="${APP_USER}"

#
# Some important labels
#
LABEL ORG="ArkCase LLC"
LABEL MAINTAINER="ArkCase Support <support@arkcase.com>"
LABEL APP="Samba"
LABEL VERSION="${VER}"

#
# Install all apps
# The third line is for multi-site config (ping is for testing later)
#
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get -y install \
        chrony \
        krb5-config \
        krb5-user \
        ldap-utils \
        libnss-winbind \
        libpam-krb5 \
        libpam-winbind \
        netcat-openbsd \
        net-tools \
        python3-lmdb \
        python3-ldap \
        samba \
        samba-dsdb-modules \
        samba-vfs-modules \
        smbclient \
        winbind \
      && \
    apt-get clean

#
# Declare some important volumes
#
# VOLUME /var/log/samba
# VOLUME /var/lib/samba

ENV APP_USER="${APP_USER}"
ENV APP_UID="${APP_UID}"
ENV APP_GROUP="${APP_GROUP}"
ENV APP_GID="${APP_GID}"

ENV HOME_DIR="/var/lib/samba"
ENV LOGS_DIR="/var/log/samba"

#
# Run Samba as non-root!
#
# More info here, if needed: https://github.com/dperson/samba/issues/170
#
RUN rm -rf "${HOME_DIR}" "${LOGS_DIR}" && \
    groupadd --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}" && \
    mkdir -p "${HOME_DIR}" "${LOGS_DIR}" && \
    chown -R "${APP_USER}:${APP_GROUP}" "${HOME_DIR}" "${LOGS_DIR}" /etc/samba /etc/krb5.conf && \
    chmod -R u=rwX,g=rX,o= "${HOME_DIR}" "${LOGS_DIR}" /etc/samba /etc/krb5.conf && \
    setcap \
        "cap_net_bind_service=ep" /usr/sbin/samba \
        "cap_net_bind_service=ep" /usr/sbin/smbd \
        "cap_net_bind_service=ep" /usr/sbin/winbindd

EXPOSE 389
EXPOSE 636

#
# Set up script and run
#
COPY --chown=root:root --chmod=0444 samba-directory-templates.tar.gz /
COPY --chown=root:root --chmod=0755 entrypoint test-ready.sh test-live.sh test-startup.sh /
COPY --chown=root:root --chmod=0755 search /usr/local/bin/

#
# Allow non-root allocation of low ports
#
# RUN setcap 'cap_net_bind_service=ep' /usr/sbin/smbd

#
# Add the configuration file templates
#
COPY --chown=root:root smb.conf.template /etc/samba/
COPY --chown=root:root krb5.conf.template /etc/

# STIG Remediations
RUN --mount=type=bind,target=/src \
    STIG="/usr/share/stig" && \
    cp -r /src/stig "${STIG}" && \
    cd "${STIG}" && \
    ./run-all && \
    cd / && \
    rm -rf "${STIG}"

#
# Fix ownerships!
#
RUN chown -R "${APP_USER}:${APP_GROUP}" /etc/samba && \
    chmod -R u=rwX,g=rX,o= /etc/samba

#
# Run as non-root!
#
USER "${APP_USER}"

HEALTHCHECK CMD /test-ready.sh

ENTRYPOINT [ "/entrypoint" ]
