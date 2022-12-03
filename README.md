# Keycloak Builder Script
The script contained in this repository (`setup.sh`) will create a custom keycloak image.
Please keep in mind, that the resulting image is meant to be used behind a reverse proxy. Thats why
you cannot add your own SSL certificate files. SSL should be handled by the reverse proxy when communicating
with the client. For that, the proxy mode of keycloak is set to `KC_PROXY=edge`.

## Requirements
1. Docker
2. Docker Compose (docker-compose supporting `docker-compose.yml` files with version `2.3`)

## Usage
```bash
wget https://raw.githubusercontent.com/TSAlliance/alliance-keycloak/main/setup.sh && chmod 760 setup.sh && ./setup.sh
```

# What the script does
Upon script execution, two files are generated.
The first file is a `Dockerfile` which desribes how the keycloak image should look like. All required information
will be asked by the script.
Additionally a `docker-compose.yml` file will be generated. This docker compose file will contain 3 services, one is 
a mariadb instance without port mapping. The second service is `phpmyadmin` to view your database and then there is
the actual keycloak service with environment variables set.
