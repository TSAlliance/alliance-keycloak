# Alliance Keycloak Image
This repository contains several files for building a docker image.
For security reasons, sensitive data was removed from the file and have to be
configured manually before building the image.

## Usage via install.sh
```bash
wget https://raw.githubusercontent.com/TSAlliance/alliance-keycloak/main/install.sh && chmod 760 install.sh && ./install.sh
```

## Table of Contents
1. Using the Dockerfile
    1. Admin credentials
    2. Database configuration
    3. Let's Encrypt Certificates
    4. Port and Hostname
2. Keycloak behind a reverse proxy
3. Using docker-compose [WIP]
4. Install using install.sh [WIP]


## 1. Using the Dockerfile
Using the `Dockerfile` is pretty straight-forward. But before using the build command, some configurations have to be done.

#### 1.1 Admin credentials
One of which is `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD` on line 13 and 14. It is important to define some secure
credentials here, otherwise it may result in your keycloak server being compromised by third parties.

#### 1.2 Datbase configuration
Configuring database connectivity settings also is straight-forward. For that you can consult lines 5 and 17-19. When it comes to configuring the database's Host address, this may vary depending on the OS docker is running on. For Linux, the host IP address for docker is always `172.17.0.1`. For Windows and MacOS you must find a way to get the image to comunicate with the mysql server on your own. This repository was written for a use case, where the mysql-server is running bare-metal instead of in a docker container. That's why the host's ip address is needed here (`localhost` will not work in that case).

#### 1.3 TLS Certificates
When building the image, make sure your certificate files, especially `fullchain.pem` and `privkey.pem` are placed inside the `cert/` folder. Those files will be copied to the docker image and therefor must be owned by the current user when build steps are performed (chown). Please consider changing permissions accordingly (chmod).

#### 1.4 Port and Hostname
You may want to configure the ports and hostname that Keycloak will use later on. Please consult lines 34, 35 and 42. The default ports are `8888` (https) and `8887` (http).


## 2. Keycloak behind a reverse proxy
When using Nginx as a reverse proxy, please consider changing the `KC_PROXY` env variable to your needs. The default value will work for most standard configurations of nginx (after a fresh install and no extraordinary configurations).



## 3. Using docker-compose
WiP

## 4. Install using install.sh
WiP

