#
# Basic Parameters
#
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG PRIVATE_REGISTRY
ARG BASE_VER_PFX=""
ARG ARCH="x86_64"
ARG OS="linux"
ARG VER="22.04"
ARG PKG="samba"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base"
ARG BASE_VER="${VER}"
ARG BASE_VER_PFX="${BASE_VER_PFX}"
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}:${BASE_VER_PFX}${BASE_VER}"

FROM "${BASE_IMG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG PKG

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
RUN apt-get update && \
    apt-get -y dist-upgrade && \
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
    apt-get clean

#
# Declare some important volumes
#
VOLUME /var/log/samba
VOLUME /var/lib/samba

EXPOSE 389
EXPOSE 636

#
# Set up script and run
#
COPY --chown=root:root --chmod=0755 entrypoint test-ready.sh test-live.sh test-startup.sh /
COPY --chown=root:root --chmod=0755 search /usr/local/bin/

#
# Add the configuration file templates
#
COPY --chown=root:root smb.conf.template /etc/samba/
COPY --chown=root:root krb5.conf.template /etc/

# STIG Remediations
COPY --chown=root:root stig/ /usr/share/stig/
RUN cd /usr/share/stig && ./run-all

# This is required by acme-init. It's ok to set it to root for this container
ENV ACM_GROUP="root"

HEALTHCHECK CMD /test-ready.sh

ENTRYPOINT [ "/entrypoint" ]
