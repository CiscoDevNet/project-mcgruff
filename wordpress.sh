#!/bin/bash

docker volume create --name wordpress_data
docker run -it -d --name opencart \
  -p 8080:8080 -p 8443:8443 \
  --env WORDPRESS_DB_USER=administrator \
  --env WORDPRESS_DB_PASSWORD=Cisco!123 \
  --env WORDPRESS_DB_USER=administrator \
  --env WORDPRESS_DB_PASSWORD=Cisco!123 \
  --env WORDPRESS_DB_NAME=wordpress \
  --network test-network \
  --volume wordpress_data:/var/www/html \
  wordpress:php8.3-apache