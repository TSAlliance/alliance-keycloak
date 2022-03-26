#!/bin/bash
sudo read -p "Enter Docker-Compose V2 Version [2.2.3]: " composeVersion
sudo read -p "Enter Container name [alliance_keycloak]: " container
sudo read -p "Enter Image name [alliance_keycloak]: " image


sudo read -p "Enter Keycloak root username [root]: " username
sudo read -p "Enter Keycloak root password [root]: " password
sudo read -p "Enter Keycloak hostname [172.17.0.1]: " hostname
sudo read -p "Enter Keycloak https port [8888]: " httpsPort

sudo read -p "Enter MySQL-Host [172.17.0.1]: " dbHost
sudo read -p "Enter MySQL-Port [3306]: " dbPort
sudo read -p "Enter MySQL-User [keycloak]: " dbUser
sudo read -p "Enter MySQL-Password [password]: " dbPass
sudo read -p "Enter MySQL-Database [keycloak]: " dbName

composeVersion=${composeVersion:-2.2.3}
container=${container:-alliance_keycloak}
image=${image:-alliance_keycloak}
hostname=${hostname:-172.17.0.1}

dbHost=${dbHost:-172.17.0.1}
dbPort=${dbPort:-3306}
dbUser=${dbUser:-keycloak}
dbPass=${dbPass:-password}
dbName=${dbName:-keycloak}

username=${username:-root}
password=${password:-root}


echo "You selected version $composeVersion for docker-compose V2"

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install dependencies to add GPG Key for docker
sudo apt-get install ca-certificates curl gnupg lsb-release tee sed

# Update container name in compose
sudo sed -e "s/*container_name*/container_name: $container/" docker-compose.yml
sudo sed -e "s/*8888:8888*/- \"httpsPort:8888\": $container/" docker-compose.yml


# Update Dockerfile
sudo sed -e "s/*KEYCLOAK_ADMIN*/ENV KEYCLOAK_ADMIN=$username/" Dockerfile
sudo sed -e "s/*KEYCLOAK_ADMIN_PASSWORD*/ENV KEYCLOAK_ADMIN_PASSWORD=$password/" Dockerfile

sudo sed -e "s/*KC_HOSTNAME*/ENV KC_HOSTNAME=$hostname/" Dockerfile
sudo sed -e "s/*KC_DB_USERNAME*/ENV KC_DB_USERNAME=$dbUser/" Dockerfile
sudo sed -e "s/*KC_DB_PASSWORD*/ENV KC_DB_PASSWORD=$dbPass/" Dockerfile
sudo sed -e "s/*KC_DB_URL_DATABASE*/ENV KC_DB_URL_DATABASE=$dbName/" Dockerfile
sudo sed -e "s/*KC_DB_URL_HOST*/ENV KC_DB_URL_HOST=$dbHost:$dbPort/" Dockerfile

sudo sed -e "s/*KC_HTTPS_PORT*/ENV KC_HTTPS_PORT=$httpsPort/" Dockerfile

# Add GPG Key for docker repo
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Setup repository list entry
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update system packages to get new versions of docker
sudo apt update

# Install docker
sudo apt-get install docker-ce docker-ce-cli containerd.io

# Enable for auto start
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Download docker compose
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v$composeVersion/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose

# Add Executable permissions
sudo chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# Setup https files to be included in keycloak image
# (See Dockerfile)
mkdir cert
sudo cp $fullchain cert/fullchain.pem
sudo cp $privKey cert/privkey.pem
sudo chown $USER:$USER -R cert/*

# Build keycloak image
docker build -t $image .
docker compose up -d
echo Done.

# Configure service file
#sudo sed -e "s/*ExecStart*/ExecStart=docker container start $container/" keycloak.service
#sudo sed -e "s/*ExecStop*/ExecStop=docker container stop $container/" keycloak.service

# Copy service to systemd and enable startup
#sudo cp keycloak.service /etc/systemd/system/keycloak.service
#sudo systemctl daemon-reload
#sudo systemctl enable keycloak.service

# Start service
#sudo service keycloak start