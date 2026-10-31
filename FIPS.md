# FIPS

Samba's TLS (LDAPS on 636, SMB3 encryption) is **unfixable** with respect to
FIPS: no configuration change to this container, the base image, or any
openssl.cnf can put Samba's crypto on the FIPS OpenSSL provider.

## Why

The stock `samba` 4.19.5 package on Ubuntu 24.04 is built with GnuTLS as its
TLS backend — `libgnutls.so.30` is a NEEDED dependency of the core
`libsamba-util`, `libsamba-hostconfig`, and `libsamba-credentials` libraries,
and the `smbd`/`samba` binaries carry zero OpenSSL symbols. The Samba KDC
uses Samba's bundled MIT Kerberos, which runs on Samba's internal crypto
(`libhcrypto-samba4.so.0` links no OpenSSL). GnuTLS has no FIPS-validated
module and no configuration path to one, so the `fips=yes` provider
configuration shipped by the FIPS variant of `arkcase/ubuntu` is simply
unreachable from Samba's crypto.

What the FIPS base image *does* cover in this container is the OpenSSL
clients (the `openssl` CLI, `ldapsearch` in `search`/`dns-update`, curl) —
their usage of the FIPS provider is independent of Samba's server-side
GnuTLS.

## Rejected alternatives

- **Rebuild Samba against OpenSSL-FIPS** (drop GnuTLS at build time): this is
  the only way to make Samba's TLS itself go through the FIPS provider, and
  it requires a custom Samba build, which we do not do.
- **Terminate LDAPS at a FIPS-validated TLS terminator in front of Samba**
  (e.g. HAProxy in FIPS mode) and run Samba's LDAPS unencrypted internally:
  moves the TLS layer out of Samba but adds a hop, shifts the trust anchor to
  the terminator's certificate, and leaves SMB3 encryption (SMB over
  clients) still on GnuTLS — so the gap is only partially closed.

Conclusion: LDAPS and SMB3 encryption in this container run through GnuTLS
and remain a documented, accepted exception to FIPS coverage.
