# redis-tls-updater

Trigger a config update to Redis when the TLS config files changes (hardcoded for testing..)

## Build

docker build -t redis-tls-updater:0.1.0 .

## Upload to kind

kind load docker-image redis-tls-updater:0.1.0
