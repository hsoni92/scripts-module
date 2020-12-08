#!/usr/bin/env bash

# Source for fetching constants
source $PWD/docker-config.sh
validInputsArr=('prod-server' 'build')

# Color Variables
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

# Args:
# start-new-apache <Container Name> <Local Build Dir> <Apache HTTP Port>
function start-new-apache() {
  # override only if all 3 input are given
  if [ "$#" -eq 3 ]; then
    CONTAINER_NAME="$1"
    LOCAL_BUILD_DIR="$2"
    APACHE_PORT="$3"
  fi
  printf "${GREEN}Creating Apache Server: $CONTAINER_NAME${NC}\n"
  echo "Local Volume Mount: $LOCAL_BUILD_DIR"
  echo "Port: $APACHE_PORT"
  printf "\n"
  echo "==================================="
  # Docker check
  if [ -x "$(command -v docker)" ]; then
      printf "${GREEN}Linux Dependency: docker is already installed${NC}\n"
  else
      echo "---- Install docker"
      sudo apt-get install docker.io -y
      sudo groupadd docker
      sudo usermod -aG docker $USER
      newgrp docker
      sudo chmod 777 /var/run/docker.sock
  fi
  
  # Delete Existing container if any
  if [ "$(docker ps -q -a -f name=$CONTAINER_NAME)" ]
    then
      printf "Container: ${YELLOW}$CONTAINER_NAME found. Destroying.${NC}\n"
      docker stop $CONTAINER_NAME
      docker rm $CONTAINER_NAME
    else
      printf "Container: ${YELLOW}$CONTAINER_NAME does not exist. Skip Destroy.${NC}\n"
  fi
  
  # Deploy Container
  if [ ! -z $(docker images -q $IMAGE_NAME) ]
  then
    echo "Docker Image: $IMAGE_NAME already present. Skip Install."
  else
    echo "Docker Image: $IMAGE_NAME NOT present. Installing:"
    sudo docker pull $IMAGE_NAME
  fi
  sudo docker run --name=$CONTAINER_NAME -v $PWD/$LOCAL_BUILD_DIR:/app -p "0.0.0.0:$APACHE_PORT":80 -t -d $IMAGE_NAME
  echo "Wait for Container services to start:"
  sleep 5
  while [[ ! "$(docker logs $CONTAINER_NAME)" =~ .*"apache2 entered RUNNING state".* ]]
    do sleep 2
  done
  echo "Docker Services have started."
  show-docker-details
}

function deploy-steps() {
  printf "Container: ${YELLOW}$CONTAINER_NAME found. Deploying build${NC}\n"
  # custom build steps here:
  # ============================
  npm run build
  cp public/.htaccess build/
  cp public/favicon.ico build/
  cp public/favicon.png build/
  cp public/favicon.svg build/
  cp public/logo192.png build/
  cp public/logo512.png build/
  cp public/manifest.json build/
  # ============================
  # Docker restart
  docker restart $CONTAINER_NAME
  show-docker-details
}

function show-docker-details() {
  printf "\n\n\nDeployment Finshed:\n"
  printf "===================================\n"
  printf "Container Name: ${GREEN}$CONTAINER_NAME${NC}\n"
  printf "Apache Server URL: ${YELLOW}http://localhost:$APACHE_PORT${NC}\n\n"
  echo "==================================="
  printf "\n\n\n"
}

function deploy-build() {
  # rebuild /build and restart apache
  if [ "$(docker ps -q -a -f name=$CONTAINER_NAME)" ]
    then
      deploy-steps
    else
      printf "Container: ${YELLOW}$CONTAINER_NAME does not exist${NC}\n"
      printf "Creating New Container: ${YELLOW}$CONTAINER_NAME${NC}\n"
      start-new-apache
      deploy-steps
  fi
}


# Calling functions:
echo "==================="
printf "| ${GREEN}Apache Deployer${NC} |\n"
echo "==================="
printf "\n"

# Validate if empty input
if [ -z "$1" ]
  then
    printf "No argument supplied\nExpected: ${validInputsArr[*]}\n"
    return 1 2>/dev/null
    exit 1
fi

# Read Input
if [ "$1" == "${validInputsArr[0]}" ]; then
  printf "Executing: ${YELLOW}${validInputsArr[0]}${NC}\n"
  start-new-apache
elif [ "$1" == "${validInputsArr[1]}" ]; then
  printf "Executing: ${YELLOW}${validInputsArr[1]}${NC}\n"
  deploy-build
else
  printf "Invalid argument: $1\nExpected: ${validInputsArr[*]}\n\n"
  return 1 2>/dev/null
  exit 1
fi
printf "\n"