#
# Basic Parameters
#
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG PRIVATE_REGISTRY
ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_VER_PFX=""
ARG ARCH="x86_64"
ARG OS="linux"
ARG VER="22.04"
ARG PKG="samba"

ARG STEP_REBUILD_REGISTRY="${PRIVATE_REGISTRY}"
ARG STEP_REBUILD_REPO="arkcase/rebuild-step-ca"
ARG STEP_REBUILD_TAG="latest" 
ARG STEP_REBUILD_IMG="${STEP_REBUILD_REGISTRY}/${STEP_REBUILD_REPO}:${STEP_REBUILD_TAG}"

ARG BASE_REPO="ubuntu"
ARG BASE_VER="22.04"
ARG BASE_IMG="${BASE_REPO}:${BASE_VER}"

ARG ARK_BASE_REGISTRY="${BASE_REGISTRY}"
ARG ARK_BASE_REPO="arkcase/base"
ARG ARK_BASE_VER="8"
ARG ARK_BASE_VER_PFX="${BASE_VER_PFX}"
ARG ARK_BASE_IMG="${ARK_BASE_REGISTRY}/${ARK_BASE_REPO}:${ARK_BASE_VER_PFX}${ARK_BASE_VER}"

FROM "${ARK_BASE_IMG}" AS arkcase-base

FROM "${STEP_REBUILD_IMG}" AS step

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
    apt-get -y install \
        acl \
        attr \
        bind9-utils \
        chrony \
        dnsutils \
        findutils \
        krb5-config \
        krb5-user \
        libnss-winbind \
        libpam-krb5 \
        libpam-winbind \
        libpam-pwquality \
        netcat-openbsd \
        net-tools \
        python3 \
        python-is-python3 \
        samba \
        samba-dsdb-modules \
        samba-vfs-modules \
        smbclient \
        winbind \
      && \
    apt-get clean

# Install STEP
COPY --chown=root:root --chmod=0755 --from=step /step /usr/local/bin/

#
# Declare some important volumes
#
VOLUME /var/log/samba
VOLUME /var/lib/samba

EXPOSE 389
EXPOSE 636

#
# Copy from the base image
#
COPY --chown=root:root --from=arkcase-base /.functions /.functions
COPY --chown=root:root --from=arkcase-base /usr/local/bin/* /usr/local/bin

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
