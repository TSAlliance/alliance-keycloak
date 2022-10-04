#!/bin/bash

CERT_FILE=cert/fullchain.pem
PRIVKEY_FILE=cert/privkey.pem

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

# Ask user for a required password
# This will ask for input as long as there
# is no value.
# $1 - Message to print to the user
getPasswordInput() {
    unset INPUT

    # Ask for input as long as there 
    # is no valid value
    while [[ $INPUT = "" ]]; do
        clear
        read -s -p "$1" INPUT
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

# Replace a line in a file
# $1 - Regex
# $2 - Replacement
# $3 - File
replace() {
    sudo sed -i.bak -e "s/$1/$2/g" $3
}

installDocker() {
    sudo apt-get install ca-certificates curl gnupg lsb-release tee sed

    # Add GPG Key for docker repo
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    # Setup repository list entry
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install docker
    sudo apt -qq update 2> /dev/null 2>&1
    sudo apt -qq install docker-ce docker-ce-cli containerd.io -y 2> /dev/null 2>&1

    # Enable for auto start
    sudo systemctl enable docker.service
    sudo systemctl enable containerd.service

    # Ask for compose version
    getOptionalInput "Which docker-compose version should be installed? [Default: 2.2.3]" "2.2.3"
    composeVersion=$INPUT

    # # Download docker compose
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/v$composeVersion/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose

    # Add Executable permissions
    sudo chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

    # Clear Terminal
    clear
}

detectCertificate() {
    if [[ ! -f CERT_FILE || ! -f PRIVKEY_FILE ]]; then
        echo " "
        echo "Either file $CERT_FILE or $PRIVKEY_FILE is missing. Both are required for setting up a secured keycloak image."
        echo " "
        exit;
    fi
}

# Clear terminal window at beginning of script
clear

detectCertificate

echo "Is Docker already installed on this system? If not, do you want to install it?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) installDocker; break;;
        No ) break;;
    esac
done

# Update system packages
echo " "
echo "[1] Checking for system updates..."
sudo apt -qq update 2> /dev/null 2>&1
echo " "

# Install updates if available
echo " "
echo "[2] Installing updates..."
sudo apt -qq upgrade -y 2> /dev/null 2>&1
echo " "

# Install sed if not exists
echo "[3] Installing sed package..."
sudo apt -qq install sed -y 2> /dev/null 2>&1
echo " "

# Ask to continue and clear terminal window afterwards
read -p "Continue with setting up keycloak image by pressing [ENTER]"
clear


#
#
#       Keycloak Section
#
#
# Ask user for keycloak version
getOptionalInput "Enter Keycloak Version [Default: latest]: " "latest"
version=$INPUT

# Ask user for keycloak admin username
getRequiredInput "Enter Keycloak Admin username: "
username=$INPUT

# Ask user for keycloak admin password
getPasswordInput "Enter Keycloak Admin password: "
password=$INPUT

# Ask user for keycloak hostname
getRequiredInput "Enter Keycloak Hostname: "
hostname=$INPUT

# Ask user for keycloak version
getOptionalInput "Enter Keycloak Port [Default: 8888]: " 8888
port=$INPUT


#
#
#       MYSQL Section
#
#
# Ask user for mysql host
getRequiredInput "Enter MySQL Host: "
dbHost=$INPUT

# Ask user for mysql port
getOptionalInput "Enter MySQL Port [Default: 3306]: " 3306
dbPort=$INPUT

# Ask user for mysql database
getRequiredInput "Enter MySQL Database: "
dbName=$INPUT

# Ask user for mysql user
getRequiredInput "Enter MySQL Username: "
dbUser=$INPUT

# Ask user for mysql password
getPasswordInput "Enter MySQL Password: "
dbPass=$INPUT

# Ask user for mysql password
getOptionalInput "How should your image be named? [Default: keycloak]: " "keycloak"
IMAGE_NAME=$INPUT

# Ask to continue and clear terminal window afterwards
echo ""
echo " "
read -p "In the next step the Dockerfile is edited with your provided input. Please hit [ENTER] to proceed"
clear

# Update Keycloak specific options in Dockerfile
replace "^FROM quay.io\/keycloak\/keycloak:latest as builder" "FROM quay.io\/keycloak\/keycloak:$version as builder" ./Dockerfile
replace "^FROM quay.io\/keycloak\/keycloak:latest" "FROM quay.io\/keycloak\/keycloak:$version" ./Dockerfile

replace "^ENV KEYCLOAK_ADMIN=.*" "ENV KEYCLOAK_ADMIN=$username" ./Dockerfile
replace "^ENV KEYCLOAK_ADMIN_PASSWORD=.*" "ENV KEYCLOAK_ADMIN_PASSWORD=$password" ./Dockerfile
replace "^ENV KC_HOSTNAME=.*" "ENV KC_HOSTNAME=$hostname" ./Dockerfile
replace "^ENV KC_HTTPS_PORT=.*" "ENV KC_HTTPS_PORT=$port" ./Dockerfile

# Update MySQL specific options in Dockerfile
replace "^ENV KC_DB_USERNAME=.*" "ENV KC_DB_USERNAME=$dbUser" ./Dockerfile
replace "^ENV KC_DB_PASSWORD=.*" "ENV KC_DB_PASSWORD=$dbPass" ./Dockerfile
replace "^ENV KC_DB_URL_DATABASE=.*" "ENV KC_DB_URL_DATABASE=$dbName" ./Dockerfile
replace "^ENV KC_DB_URL_HOST=.*" "ENV KC_DB_URL_HOST=$dbHost:$dbPort" ./Dockerfile
clear

# Setup https files to be included in keycloak image
# (See Dockerfile)
sudo chown $USER:$USER -R cert/*

echo " "
echo "Building image using Dockerfile..."
echo " "
# Build keycloak image
docker build -t $IMAGE_NAME .
echo " "

# Setup successful,
# ask use if he wants to setup a container right away
clear
echo "Your Keycloak Image/Container is now ready to go."
echo " "
echo "Do you want to setup a container using docker-compose?"
select yn in "Yes" "No"; do
    case $yn in
        No ) exit;;
        Yes ) break;;
    esac
done

# Continue with setting up container using docker-compose

# Ask user for mysql port
getOptionalInput "How should your container be named? [Default: keycloak]: " "keycloak"
containerName=$INPUT

getOptionalInput "To which port should the exposed port 8888 be mapped? [Default: 8080]: " 8080
portMapping=$INPUT

clear
echo ""

sudo tee test.txt <<EOF
version: '3.9'

services:
  keycloak:
    image: $IMAGE_NAME
    restart: always
    container_name: $containerName
    ports:
      - "$portMapping:8888"
EOF

echo " "
echo " "
echo "File docker-compose.yml has been written using your provided input."
echo "If you want to edit some things, please quit this script using CTRL+C."
echo "To create the container now, press ENTER"
echo " "
echo " "

read

clear
docker compose up -d

echo "Docker container has been created using docker-compose."
echo "You can now manage the container using docker."
echo " "
exit;