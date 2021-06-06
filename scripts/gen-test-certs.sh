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
    local faketime="$3"
    local opts="$4"

    local keyfile=${dir}/${name}.key
    local certfile=${dir}/${name}.crt

    [ -f $keyfile ] || openssl genrsa -out $keyfile 2048
    openssl req \
        -new -sha256 \
        -subj "/O=Redis Test/CN=$cn" \
        -key $keyfile | \
        faketime -f ${faketime} \
            openssl x509 \
                -req -sha256 \
                -CA ${dir}/ca.crt \
                -CAkey ${dir}/ca.key \
                -CAserial ${dir}/ca.txt \
                -CAcreateserial \
                -days 1 \
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

# Create openssl config to generate specific certs
cat > ${dir}/openssl.cnf <<_END_
[ server_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = server

[ client_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = client
_END_


# Create cert's with 1 minute until expiring (60min * 24h - 1 min)
#generate_cert redis "Generic-cert" "-1439m"

#generate_cert <name> <cn> <faketime> <options>
generate_cert redis      "redis"      "+0m" "-extfile ${dir}/openssl.cnf -extensions server_cert"
generate_cert exporter-s "exporter-s" "+0m" "-extfile ${dir}/openssl.cnf -extensions server_cert"
generate_cert exporter-c "exporter-c" "+0m" "-extfile ${dir}/openssl.cnf -extensions client_cert"
generate_cert curl       "curl"       "+0m" "-extfile ${dir}/openssl.cnf -extensions client_cert"

# Let the pods read the key files
chmod 644 ${dir}/*.key
