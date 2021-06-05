#!/bin/bash

# Generates TLS certificates:
#
#   /tmp/tls-data/ca.{crt,key}          Self signed CA certificate.
#   /tmp/tls-data/redis.{crt,key}       A certificate with no key usage/policy restrictions.
#   /tmp/tls-data/exporter.{crt,key}    A certificate with no key usage/policy restrictions.
#   /tmp/tls-data/client.{crt,key}      A certificate with no key usage/policy restrictions.
dir=/tmp/tls-data

generate_cert() {
    local name=$1
    local cn="$2"
    local opts="$3"

    local keyfile=${dir}/${name}.key
    local certfile=${dir}/${name}.crt

    [ -f $keyfile ] || openssl genrsa -out $keyfile 2048
    openssl req \
        -new -sha256 \
        -subj "/O=Redis Test/CN=$cn" \
        -key $keyfile | \
        openssl x509 \
            -req -sha256 \
            -CA ${dir}/ca.crt \
            -CAkey ${dir}/ca.key \
            -CAserial ${dir}/ca.txt \
            -CAcreateserial \
            -days 365 \
            $opts \
            -out $certfile
}

# Create CA
mkdir -p ${dir}
[ -f ${dir}/ca.key ] || openssl genrsa -out ${dir}/ca.key 4096
openssl req \
    -x509 -new -nodes -sha256 \
    -key ${dir}/ca.key \
    -days 3650 \
    -subj '/O=Redis Test/CN=Certificate Authority' \
    -out ${dir}/ca.crt

# Create cert's
generate_cert redis "Generic-cert"

# Let the pods read the key files
chmod 644 ${dir}/*.key
