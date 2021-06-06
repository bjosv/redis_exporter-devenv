#!/bin/bash

# Setup a Redis instance to run towards
#docker run --name redis -d --net=host -v /tmp/tls-data/:/tls-data:ro redis:6.2 redis-server --tls-port 6379 --port 0 --tls-cert-file /tls-data/redis.crt --tls-key-file /tls-data/redis.key --tls-ca-cert-file /tls-data/ca.crt --tls-auth-clients no --loglevel debug

# Build and run a local instance for testing
go build .
WATCH_FILES=/tmp/tls-data/exporter-c.crt:/tmp/tls-data/exporter-c.key \
           REDIS_TLS_CLIENT_CERT_FILE=/tmp/tls-data/exporter-c.crt \
           REDIS_TLS_CLIENT_KEY_FILE=/tmp/tls-data/exporter-c.key \
           REDIS_TLS_CA_CERT_FILE=/tmp/tls-data/ca.crt \
           REDIS_SKIP_TLS_VERIFICATION=true \
           REDIS_URI=rediss://localhost:6379 \
./redis-tls-updater
