#!/bin/bash

ORG='HashiCorp'
DOMAIN='hashicorp.com'
ADMIN_USER='cn=admin,dc=hashicorp,dc=com'
ADMIN_PASSWORD='admin'
LDAP_IMAGE='osixia/openldap:1.3.0'
VAULT_IMAGE='vault:latest'

docker pull ${LDAP_IMAGE?}

docker run \
  --name=ldap \
  --hostname=ldap \
  --network=vault \
  -p 389:389 \
  -p 636:636 \
  -e LDAP_ORGANISATION="${ORG?}" \
  -e LDAP_DOMAIN="${DOMAIN?}" \
  -e LDAP_ADMIN_PASSWORD="${ADMIN_PASSWORD?}" \
  --detach ${LDAP_IMAGE?}

sleep 5

ldapadd -x -w ${ADMIN_PASSWORD?} -D "${ADMIN_USER?}" -f ./configs/ldap-seed.ldif

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

vault secrets enable openldap

vault write openldap/config \
  binddn="cn=admin,dc=hashicorp,dc=com" \
  bindpass="admin" \
  url="ldap://localhost" \
  password_policy=password_policy

vault write openldap/static-role/hashicorp \
  username='hashicorp' \
  dn='cn=hashicorp,ou=users,dc=hashicorp,dc=com' \
  rotation_period="5s"


vault write openldap/role/dynamic-role \
  creation_ldif=creation.ldif \
  deletion_ldif=deletion.ldif \
  rollback_ldif=rollback.ldif \
  default_ttl=1h \
  max_ttl="24h"