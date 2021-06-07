#!/bin/bash

# Generates TLS certificates:
#
#   /tmp/tls-data/ca.{crt,key}          Self signed CA certificate.
#   ...
dir=/tmp/tls-data

generate_cert() {
    local name=$1
    local cn="$2"
    local faketime="$3"
    local opts="$4"

    local keyfile=${dir}/${name}.key
    local certfile=${dir}/${name}.crt

    echo "*********************************************************"
    echo "Generate keypair for $name using faketime=$faketime"
    echo "*********************************************************"
    echo

    openssl genrsa -out $keyfile 2048
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

generate_ca() {
    openssl genrsa -out ${dir}/ca.key 4096
    openssl req \
            -x509 -new -nodes -sha256 \
            -key ${dir}/ca.key \
            -days 3650 \
            -subj '/O=Redis Test/CN=Certificate Authority' \
            -out ${dir}/ca.crt
}


mkdir -p ${dir}

# Create openssl config to generate specific certs
[ -f ${dir}/openssl.cnf ] || cat > ${dir}/openssl.cnf <<_END_
[ server_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = server

[ client_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = client
_END_

# Take specific keypair name to generate
name=$1
minutes=$2

faketime="+0m"

# Create cert's with X minute until expiring (60min * 24h - X min),
# example: 2 give faketime="-1438m"
[[ ! -z $minutes ]] && faketime="-$((1440-$minutes))m"

# Generate CA if no specific keypair name given
[[ -z $name || "$name" == "ca" ]]         && generate_ca

# Generate if no argument, or specific given
# generate_cert <name> <cn> <faketime> <options>
[[ -z $name || "$name" == "redis" ]]      && generate_cert redis      "localhost" $faketime "-extfile ${dir}/openssl.cnf -extensions server_cert"
[[ -z $name || "$name" == "exporter-s" ]] && generate_cert exporter-s "localhost" $faketime "-extfile ${dir}/openssl.cnf -extensions server_cert"
[[ -z $name || "$name" == "exporter-c" ]] && generate_cert exporter-c "localhost" $faketime "-extfile ${dir}/openssl.cnf -extensions client_cert"
[[ -z $name || "$name" == "curl" ]]       && generate_cert curl       "curlpod"   $faketime "-extfile ${dir}/openssl.cnf -extensions client_cert"

# Let the pods read the key files
chmod 644 ${dir}/*.key
