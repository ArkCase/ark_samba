#!/bin/bash

DEBUG="false"
case "${DEBUG,,}" in
	true | t | yes | y | 1 | on | active | enabled ) DEBUG="true" ;;
esac

#${DEBUG} && set -x

CONF_DIR="/config"
SMB_CONF="/etc/samba/smb.conf"
EXT_SMB_CONF="${CONF_DIR}/smb.conf"
KRB_CONF="/etc/krb5.conf"
EXT_KRB_CONF="${CONF_DIR}/krb5.conf"

#
# Set and normalize variables
#
DOMAINPASS="${DOMAINPASS:-youshouldsetapassword}"
JOIN="${JOIN:-false}"
JOINSITE="${JOINSITE:-NONE}"
MULTISITE="${MULTISITE:-false}"
NOCOMPLEXITY="${NOCOMPLEXITY:-false}"
INSECURELDAP="${INSECURELDAP:-false}"
DNSFORWARDER="${DNSFORWARDER:-NONE}"
HOSTIP="${HOSTIP:-NONE}"

DOMAIN="${DOMAIN:-SAMDOM.LOCAL}"
LDOMAIN="${DOMAIN,,}"
UDOMAIN="${DOMAIN^^}"
REALM="${UDOMAIN%%.*}"

D2=()
IFS="." D2=(${DOMAIN})
D3=()
for P in "${D2[@]}" ; do
	D3+=("DC=${P^^}")
done

DC=""
for P in "${D3[@]}" ; do
	[ -n "${DC}" ] && DC="${DC},"
	DC="${DC}${P}"
done
unset D2 D3

#
# This function will check to see if the instance can be considered
# "configured"
#
is_initialized() {
	local CANDIDATES=()

	#
	# Common data
	#
	CANDIDATES+=("account_policy.tdb")
	CANDIDATES+=("netsamlogon_cache.tdb")
	CANDIDATES+=("registry.tdb")
	CANDIDATES+=("share_info.tdb")
	CANDIDATES+=("smbprofile.tdb")
	CANDIDATES+=("winbindd_cache.tdb")
	CANDIDATES+=("wins.ldb")

	#
	# Private data
	#
	CANDIDATES+=("private/dns_update_cache")
	CANDIDATES+=("private/dns_update_list")
	CANDIDATES+=("private/encrypted_secrets.key")
	CANDIDATES+=("private/hklm.ldb")
	CANDIDATES+=("private/idmap.ldb")
	CANDIDATES+=("private/kdc.conf")
	CANDIDATES+=("private/krb5.conf")
	CANDIDATES+=("private/netlogon_creds_cli.tdb")
	CANDIDATES+=("private/privilege.ldb")
	CANDIDATES+=("private/sam.ldb")
	CANDIDATES+=("private/schannel_store.tdb")
	CANDIDATES+=("private/secrets.keytab")
	CANDIDATES+=("private/secrets.ldb")
	CANDIDATES+=("private/secrets.tdb")
	CANDIDATES+=("private/share.ldb")
	CANDIDATES+=("private/spn_update_list")
	CANDIDATES+=("private/wins_config.ldb")

	#
	# SSL Certificates
	#
	CANDIDATES+=("private/tls/ca.pem")
	CANDIDATES+=("private/tls/cert.pem")
	CANDIDATES+=("private/tls/key.pem")

	#
	# Domain configurations
	#
	CANDIDATES+=("private/sam.ldb.d/metadata.tdb")
	CANDIDATES+=("private/sam.ldb.d/CN=CONFIGURATION,${DC}.ldb")
	CANDIDATES+=("private/sam.ldb.d/CN=SCHEMA,CN=CONFIGURATION,${DC}.ldb")
	CANDIDATES+=("private/sam.ldb.d/DC=DOMAINDNSZONES,${DC}.ldb")
	CANDIDATES+=("private/sam.ldb.d/DC=FORESTDNSZONES,${DC}.ldb")
	CANDIDATES+=("private/sam.ldb.d/${DC}.ldb")

	#
	# Check for the created databases
	#
	local PFX="/var/lib/samba"
	for C in "${CANDIDATES[@]}" ; do
		C="${PFX}/${C}"
		[ -e "${C}" ] || return 1
		[ -f "${C}" ] || return 1
		[ -r "${C}" ] || return 1
	done

	#
	# Domain Policies
	#
	local POLICY_DIR="${PFX}/sysvol/${DOMAIN,,}/Policies"
	[ -e "${POLICY_DIR}" ] || return 1
	[ -d "${POLICY_DIR}" ] || return 1
	[ -r "${POLICY_DIR}" ] || return 1
	[ -x "${POLICY_DIR}" ] || return 1

	#
	# Is this correct? Can a domain exist with no policies?
	#
	# TODO: disabled for now, as additional DCs don't seem to copy them over
	#local POLICIES=$(find "${POLICY_DIR}" -type f -iname GPT.INI | wc -l)
	#[ "${POLICIES}" -lt 1 ] && return 1

	#
	# We're fully configured, so we don't have to redo it
	#
	return 0
}

${DEBUG} && set -x
CERTS="$(openssl s_client -connect localhost:636 -showcerts </dev/null 2>1)"
RC=${?}
${DEBUG} && set +x
if [ ${RC} -ne 0 ] ; then
	echo -e "Failed to get the SSL certificates from the LDAPS server"
	echo -e "${CERTS}"
	exit 1
fi
echo -e "Port 636/tcp seems to be listening and serving out certificates"
${DEBUG} && echo -e "${CERTS}"

${DEBUG} && set -x
LDAP="$(ldapsearch -H ldaps://localhost:636 -D "${REALM}\administrator" -w "${DOMAINPASS}" -b "${DC}" '(objectClass=user)' dn 2>&1)"
RC=${?}
${DEBUG} && set +x
if [ ${RC} -ne 0 ] ; then
	echo -e "Failed to execute a test LDAPS query"
	echo -e "${LDAP}"
	exit 1
fi
echo -e "LDAP Search successful:"
${DEBUG} && echo -e "${LDAP}"

# All appears to be well!
echo -e "The instance is live"
exit 0
