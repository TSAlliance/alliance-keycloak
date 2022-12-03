#!/bin/bash

CERT_FILE=cert/fullchain.pem
PRIVKEY_FILE=cert/privkey.pem

DOCKER_IMG_TAG=keycloak_tscb:latest

MARIADB_CONTAINER_NAME=mariadb

# Ask user for a required input
# This will ask for input as long as there
# is no value.
# $1 - Message to print to the user
getRequiredInput() {
    unset INPUT

    # Ask for input as long as there 
    # is no valid value
    while [[ $INPUT = "" ]]; do
        clear
        read -p "$1" INPUT
    done
}

# Ask user for an optional input
# $1 - Message to print to the user
# $2 - Default value
getOptionalInput() {
    unset INPUT

    # Ask for input as long as there 
    # is no valid value
    clear
    read -p "$1" INPUT

    INPUT=${INPUT:-"$2"}
}

detectCertificate() {
    if [ ! -f "$CERT_FILE" ] || [ ! -f "$PRIVKEY_FILE" ]; then
        echo " "
        echo "Either file $CERT_FILE or $PRIVKEY_FILE is missing. Both are required for setting up a secured keycloak image."
        echo " "
        exit;
    fi

    echo " "
    echo "Please enter passwort to perform permission changes for cert files"
    echo " "
    # Setup https files to be included in keycloak image
    # (See Dockerfile)
    sudo chown $USER:$USER -R ssl/* >> /dev/null
}

clear
#detectCertificate

# Install sed if not exists
echo "[3] Installing sed package..."
sudo apt -qq install sed -y 2> /dev/null 2>&1
echo " "

clear

# Ask user for keycloak version
getOptionalInput "Enter Keycloak Version [Default: latest]: " "latest"
kc_version=$INPUT

# Ask user for keycloak admin username
getOptionalInput "Enter Keycloak Admin username [Default: root]: " "root"
kc_username=$INPUT

# Ask user for keycloak admin password
getRequiredInput "Enter Keycloak Admin password: "
kc_password=$INPUT

# Ask user for keycloak hostname
getOptionalInput "Enter Keycloak Hostname [Default: localhost]: " "localhost"
kc_hostname=$INPUT

# Ask user for keycloak port
getOptionalInput "Enter Keycloak docker port [Default: 51973]: " 51973
kc_port=$INPUT

# Write dockerfile
sudo tee Dockerfile <<EOF
FROM quay.io/keycloak/keycloak:$kc_version as builder

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Configure a database vendor
ENV KC_DB=mariadb

WORKDIR /opt/keycloak

# Build the image
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:$kc_version
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# change these values to point to a running mysql instance
ENV KC_DB_URL_PROPERTIES=?characterEncoding=UTF-8

ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start", "--optimized"]
EOF

echo " "
echo "Building image using Dockerfile..."
echo " "
# Build keycloak image
docker build . -t $DOCKER_IMG_TAG
echo " "
echo " "
echo " "
echo "Hit [ENTER] to continue"
read
clear

echo " "
echo "Collecting information on mariadb instance"
echo " "

# Ask user for mysql password
getOptionalInput "Enter MariaDB root password [Default: root]: " "root"
mariadb_root_pw=$INPUT

getOptionalInput "Enter MariaDB keycloak username [Default: keycloak]: " "keycloak"
mariadb_keycloak_name=$INPUT

getRequiredInput "Enter MariaDB keycloak password: "
mariadb_keycloak_pw=$INPUT

getOptionalInput "Enter PHPMyAdmin docker port [Default: 43164]: " 43164
pma_docker_port=$INPUT

clear
# Write docker-compose file
sudo tee docker-compose.yml <<EOF
version: '2.3'

services:
  database:
    image: mariadb:latest
    container_name: $MARIADB_CONTAINER_NAME
    restart: always
    environment:
      - MARIADB_ROOT_PASSWORD=$mariadb_root_pw
    networks:
      - alliance_docker_network

  authentication:
    image: $DOCKER_IMG_TAG
    container_name: keycloak
    restart: always
    depends_on:
      - database
    ports:
      - "$kc_port:8080"
    environment:
      # Database connection options
      - KC_DB_URL=jdbc:mariadb://database:3306/$mariadb_keycloak_name
      - KC_DB_PASSWORD=$mariadb_keycloak_pw
      - KC_DB_USERNAME=$mariadb_keycloak_name

      # Keycloak root user options
      - KEYCLOAK_ADMIN=$kc_username
      - KEYCLOAK_ADMIN_PASSWORD=$kc_password

      # Proxy settings
      - KC_PROXY=edge

      # Hostname settings
      - KC_HOSTNAME=$kc_hostname
      - KC_HOSTNAME_STRICT=false
    networks:
      - alliance_docker_network

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: phpmyadmin_mariadb
    restart: always
    depends_on:
      - database
    ports:
      - "$pma_docker_port:80"
    environment:
      - MYSQL_ROOT_PASSWORD=$mariadb_root_pw
      - PMA_HOST=database
    networks:
      - alliance_docker_network

networks:
  alliance_docker_network:
EOF

echo " "
echo "Setting up mariadb"
docker-compose up -d --no-deps database

echo "Waiting for mariadb to be ready..."
while ! docker exec $MARIADB_CONTAINER_NAME mariadb --user=root --password=$mariadb_root_pw -e "status" &> /dev/null ; do
    sleep 2
done

echo " "
echo "Creating keycloak database (called: $mariadb_keycloak_name)..."

docker exec -it $MARIADB_CONTAINER_NAME mariadb --user root -p$mariadb_root_pw -e "CREATE DATABASE IF NOT EXISTS $mariadb_keycloak_name;"
docker exec $MARIADB_CONTAINER_NAME mariadb --user root -p$mariadb_root_pw -e "CREATE USER IF NOT EXISTS '$mariadb_keycloak_name'@'%' IDENTIFIED BY '$mariadb_keycloak_pw';"
docker exec $MARIADB_CONTAINER_NAME mariadb --user root -p$mariadb_root_pw -e "GRANT ALL PRIVILEGES ON $mariadb_keycloak_name.* TO '$mariadb_keycloak_name'@'%';"
docker exec $MARIADB_CONTAINER_NAME mariadb --user root -p$mariadb_root_pw -e "FLUSH PRIVILEGES;"

echo "Setting up all containers"
docker-compose up -d