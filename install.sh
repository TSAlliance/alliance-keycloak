#!/bin/bash
sudo read -p "Enter Docker-Compose V2 Version [2.2.3]: " composeVersion
sudo read -p "Enter Container name [alliance_keycloak]: " container
sudo read -p "Enter Image name [alliance_keycloak]: " image


sudo read -p "Enter Keycloak root username: " username
sudo read -p "Enter Keycloak root password: " password

#sudo read -p "Enter MySQL-Host [localhost]: " dbHost
#sudo read -p "Enter MySQL-Port [3306]: " dbPort
#sudo read -p "Enter MySQL-User [root]: " dbUser
#sudo read -p "Enter MySQL-Password [root]: " dbPass
#sudo read -p "Enter MySQL-Database [keycloak]: " dbName

composeVersion=${composeVersion:-2.2.3}
container=${container:-alliance_keycloak}
image=${image:-alliance_keycloak}


#dbHost=${dbHost:-localhost}
#dbPort=${dbPort:-3306}
#dbUser=${dbUser:-root}
#dbPass=${dbPass:-root}
#dbName=${dbName:-keycloak}

echo "You selected version $composeVersion for docker-compose V2"

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install dependencies to add GPG Key for docker
sudo apt-get install ca-certificates curl gnupg lsb-release tee sed

# Update root username and password
#sudo sed -e "s/*KEYCLOAK_USER*/- KEYCLOAK_USER=$username/" docker-compose.yml
#sudo sed -e "s/*KEYCLOAK_PASSWORD*/- KEYCLOAK_PASSWORD=$username/" docker-compose.yml
#sudo sed -e "s/*DB_ADDR*/- DB_ADDR=$dbHost/" docker-compose.yml
#sudo sed -e "s/*DB_PORT*/- DB_PORT=$dbPort/" docker-compose.yml
#sudo sed -e "s/*DB_DATABASE*/- DB_DATABASE=$dbName/" docker-compose.yml
#sudo sed -e "s/*DB_USER*/- DB_USER=$dbUser/" docker-compose.yml
#sudo sed -e "s/*DB_PASSWORD*/- DB_PASSWORD=$dbPass/" docker-compose.yml

# Update container name in compose
sudo sed -e "s/*container_name*/container_name: $container/" docker-compose.yml

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
sleep 5
docker container stop $container

# Configure service file
sudo sed -e "s/*ExecStart*/ExecStart=docker container start $container/" keycloak.service
sudo sed -e "s/*ExecStop*/ExecStop=docker container stop $container/" keycloak.service

# Copy service to systemd and enable startup
sudo cp keycloak.service /etc/systemd/system/keycloak.service
sudo systemctl daemon-reload
sudo systemctl enable keycloak.service

# Start service
sudo service keycloak start