#
# Basic Parameters
#
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG PRIVATE_REGISTRY
ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_VER_PFX=""
ARG ARCH="x86_64"
ARG OS="linux"
ARG VER="4.14.5"
ARG PKG="samba"

ARG STEP_REBUILD_REGISTRY="${PRIVATE_REGISTRY}"
ARG STEP_REBUILD_REPO="arkcase/step-rebuild"
ARG STEP_REBUILD_TAG="latest" 
ARG STEP_REBUILD_IMG="${STEP_REBUILD_REGISTRY}/${STEP_REBUILD_REPO}:${STEP_REBUILD_TAG}"

ARG SAMBA_REGISTRY="${BASE_REGISTRY}"
ARG SAMBA_REPO="arkcase/samba-rpmbuild"
ARG SAMBA_BASE_VER_PFX="${BASE_VER_PFX}"
ARG SAMBA_VER="${VER}"
ARG SAMBA_RPM_IMG="${SAMBA_REGISTRY}/${SAMBA_REPO}:${SAMBA_BASE_VER_PFX}${SAMBA_VER}"

ARG BASE_REPO="rockylinux"
ARG BASE_VER="8.5"
ARG BASE_IMG="${BASE_REPO}:${BASE_VER}"

ARG ARK_BASE_REGISTRY="${BASE_REGISTRY}"
ARG ARK_BASE_REPO="arkcase/base"
ARG ARK_BASE_VER="8"
ARG ARK_BASE_VER_PFX="${BASE_VER_PFX}"
ARG ARK_BASE_IMG="${ARK_BASE_REGISTRY}/${ARK_BASE_REPO}:${ARK_BASE_VER_PFX}${ARK_BASE_VER}"

FROM "${ARK_BASE_IMG}" AS arkcase-base

FROM "${STEP_REBUILD_IMG}" AS step

FROM "${SAMBA_RPM_IMG}" AS src

#
# For actual execution
#
FROM "${BASE_IMG}" AS ssg-src

# Copy the STIG file so it can be consumed by the scanner
RUN yum -y install scap-security-guide && \
    cp -vf "/usr/share/xml/scap/ssg/content/ssg-rl8-ds.xml" "/ssg-ds.xml" && \
    yum -y remove scap-security-guide && \
    yum -y clean all

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
RUN yum -y install \
        epel-release \
        yum-utils \
    && \
    yum -y update && \
    yum-config-manager --setopt=*.priority=50 --save
COPY --from=ssg-src /ssg-ds.xml /
COPY --from=src /rpm /rpm
COPY arkcase.repo /etc/yum.repos.d
RUN yum -y install \
        attr \
        authselect \
        bind-utils \
        findutils \
        krb5-pkinit \
        krb5-server \
        krb5-workstation \
        nc \
        net-tools \
        openssl \
        openldap-clients \
        python3 \
        python3-samba \
        python3-samba-dc \
        python3-pyyaml \
        samba \
        samba-dc \
        samba-dc-bind-dlz \
        samba-krb5-printing \
        samba-vfs-iouring \
        samba-winbind \
        samba-winbind-krb5-locator \
        samba-winexe \
        sssd-krb5 \
        telnet \
        which \
    && \
    yum -y clean all && \
    update-alternatives --set python /usr/bin/python3 && \
    rm -rf /rpm /etc/yum.repos.d/arkcase.repo

# Install STEP
COPY --chown=root:root --chmod=0755 --from=step /step /usr/local/bin/

#
# Declare some important volumes
#
VOLUME /app/conf
VOLUME /app/init
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
COPY --chown=root:root --chmod=0640 samba-directory-templates.tar.gz /
COPY --chown=root:root --chmod=0755 entrypoint test-ready.sh test-live.sh test-startup.sh /
COPY --chown=root:root --chmod=0755 search /usr/local/bin/

#
# Add the configuration file templates
#
COPY --chown=root:root smb.conf.template /etc/samba/
COPY --chown=root:root krb5.conf.template /etc/

# STIG Remediations
RUN authselect select minimal --force
COPY --chown=root:root stig/ /usr/share/stig/
RUN cd /usr/share/stig && ./run-all

# This is required by acme-init. It's ok to set it to root for this container
ENV ACM_GROUP="root"

HEALTHCHECK CMD /test-ready.sh

ENTRYPOINT [ "/entrypoint" ]
