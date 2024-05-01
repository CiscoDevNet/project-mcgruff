#!/bin/bash

# docker volume create --name mariadb_data
docker run -d --name mariadb \
  --env ALLOW_EMPTY_PASSWORD=yes \
  --env MARIADB_USER=administrator \
  --env MARIADB_PASSWORD=Cisco!123 \
  --env MARIADB_DATABASE=wordpress \
  --network test-network \
  bitnami/mariadb:latest