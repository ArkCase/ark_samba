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

ENV APP_UID="${APP_UID}" \
    APP_GID="${APP_GID}" \
    APP_USER="${APP_USER}" \
    APP_GROUP="${APP_GROUP}"

#
# Install all apps, and set up the scripts and configuration templates
# The third line is for multi-site config (ping is for testing later)
#
RUN --mount=type=bind,target=/src \
    umask 0007 && \
    DEBIAN_FRONTEND=noninteractive \
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
    apt-get clean && \
    groupadd --system --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --system --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --no-create-home --home-dir "/var/lib/samba" "${APP_USER}" && \
    install -o root -g root -m 0640 /src/samba-directory-templates.tar.gz / && \
    install -o root -g root -m 0755 -t /usr/local/bin /src/samba-common /src/entrypoint /src/provision /src/dns-update /src/search && \
    install -o root -g root -m 0755 -t / /src/test-ready.sh /src/test-live.sh /src/test-startup.sh && \
    install -o root -g "${APP_GROUP}" -m 0640 /src/smb.conf.template /etc/samba/ && \
    install -o root -g "${APP_GROUP}" -m 0640 /src/krb5.conf.template /etc/ && \
    install -d -o "${APP_USER}" -g "${APP_GROUP}" -m 0750 "${CONF_DIR}" /run/samba /var/lib/samba /var/log/samba && \
    ln -sfn "${CONF_DIR}/smb.conf" /etc/samba/smb.conf && \
    ln -sfn "${CONF_DIR}/krb5.conf" /etc/krb5.conf && \
    run-stig /src/stig

#
# Run as non-root! The provisioner (init container) still runs as root, and
# hands the state and logs over to ${APP_USER} before it exits. The configurations
# rendered at startup live in ${CONF_DIR} (/etc/samba/smb.conf and /etc/krb5.conf
# link there). Ports below 1024 need net.ipv4.ip_unprivileged_port_start=0 (a pod
# sysctl; Docker sets it by default).
#
USER "${APP_USER}"

EXPOSE 389
EXPOSE 636

HEALTHCHECK CMD /test-ready.sh
