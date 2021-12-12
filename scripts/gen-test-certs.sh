#!/bin/bash -e

# Generates TLS certificates:
#
#   /tmp/tls-data/ca.{crt,key}          Self signed CA certificate.
#   ...
dir=/tmp/tls-data

generate_cert() {
    local name=$1
    local cn="$2"
    local faketime="$3"
    local type="$4"

    local keyfile=${dir}/${name}.key
    local certfile=${dir}/${name}.crt

    echo "*********************************************************"
    echo "Generate keypair for $name using faketime=$faketime"
    echo "*********************************************************"
    echo
    # TODO: Depending on if `cn` is an IP or a dns name, do:
    # subjectAltName = DNS:$cn
    # subjectAltName = IP:$cn

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
                -extfile <(printf "[ EXT ]
                                  keyUsage = digitalSignature, keyEncipherment
                                  nsCertType = $type
                                  subjectAltName = IP:$cn") \
                -extensions EXT \
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

# Arguments:
#   Generated a specific keypair or empty string for all
name=$1
#   Minutes until certs expire, or skip for 1 day until expire
minutes=$2
#   Override default common name i.e the server host name
cn=${3:-'localhost'}

faketime="+0m"

# Create cert's with X minute until expiring (60min * 24h - X min),
# example: 2 give faketime="-1438m"
[[ ! -z $minutes ]] && faketime="-$((1440-$minutes))m"

# Generate CA if no specific keypair name given
[[ -z $name || "$name" == "ca" ]]         && generate_ca

# Generate if no argument, or specific given
# generate_cert <name> <common-name> <faketime> <cert-type>


[[ -z $name || "$name" == "redis" ]]      && generate_cert redis      $cn $faketime "server"
[[ -z $name || "$name" == "exporter-s" ]] && generate_cert exporter-s $cn $faketime "server"
[[ -z $name || "$name" == "exporter-c" ]] && generate_cert exporter-c $cn $faketime "client"
[[ -z $name || "$name" == "curl" ]]       && generate_cert curl       $cn $faketime "client"

# Let the pods read the key files
chmod 644 ${dir}/*.key
