#!/bin/bash

# Set variables
CONSUL_IP="172.17.0.2"
DNS_IP="8.8.8.8"
SERVER_IP="$(ip addr show eth0 | grep 'inet ' | cut -d"/" -f1 | awk '{ print $2}')"
CONSUL_TEMPLATE_URL="https://releases.hashicorp.com/consul-template"
CONSUL_TEMPLATE_VER="0.16.0"
DOCKER_COMPOSE_PATH="/vagrant/projects/docker-compose"
DOCKER_COMPOSE_VER="1.11.2"
DOCKER_PORT_RANGE="2000	2100"
DOCKER_REPO_URL="https://download.docker.com/linux/centos/docker-ce.repo"
DOCKER_VERSION="17.03.0.ce-1.el7.centos"
MYSQL_DATABASE="rancher"
MYSQL_PASSWORD="R@nch3r"
MYSQL_USER="rancher"
RANCHER_COMPOSE_URL="https://releases.rancher.com/compose/v0.12.3/rancher-compose-linux-amd64-v0.12.3.tar.gz"
RANCHER_PORT="8888"
PERCONA_VERSION='5.7.17'

# Run updates & install packages
sudo yum update -y
sudo yum check-update
sudo yum install bind-utils git mysql mlocate net-tools ntp telnet unzip yum-utils wget -y

# Disable selinux
sudo sed -i --follow-symlinks 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux

# Create ssh config
echo "StrictHostKeyChecking no" > /home/vagrant/.ssh/config

# Edit sysctrl max_map_count
sudo sysctl -w vm.max_map_count=262144
sudo echo "vm.max_map_count=262144" >> /etc/sysctl.conf

# Set timezone
sudo timedatectl set-timezone America/Chicago

# Install docker
sudo su
sudo yum-config-manager --add-repo $DOCKER_REPO_URL
sudo yum -y install docker-ce-$DOCKER_VERSION docker-ce-selinux-$DOCKER_VERSION
sudo usermod -aG docker vagrant
sudo systemctl enable docker
sudo systemctl start docker

# Install docker-compose
sudo curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VER/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Pull & launch consul container
#sudo docker run --restart=always --name=consul-server -d --net=host -e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' -e "CONSUL_LOCAL_CONFIG={\"reconnect_timeout\":\"8h\"}" consul agent -server -ui -bind=$SERVER_IP -bootstrap-expect=1 -client=0.0.0.0 -datacenter=loc -dns-port=53 -domain=vagrant.consul -recursor=$DNS_IP
sleep 10 # Give consul dns time to come online

# Install consul-template
wget $CONSUL_TEMPLATE_URL/$CONSUL_TEMPLATE_VER/consul-template_${CONSUL_TEMPLATE_VER}_linux_amd64.zip -O /tmp/consul-template.zip
unzip /tmp/consul-template.zip -d /usr/local/bin/

# Edit host DNS settings
echo "[main]" > /etc/NetworkManager/conf.d/dns.conf
echo "dns=none" >> /etc/NetworkManager/conf.d/dns.conf
systemctl restart NetworkManager.service
echo "search vagrant.consul" > /etc/resolv.conf
echo "nameserver ${SERVER_IP}" >> /etc/resolv.conf

#Edit host file
echo "${SERVER_IP}  consul.service.vagrant.consul" >> /etc/hosts

# Pull & launch registrator
#sudo docker run --restart=always --name=registrator -d --net=host --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator:latest consul://localhost:8500

# Pull & launch nginx-proxy
sudo docker run --restart=always --name=nginx-proxy -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock:ro jwilder/nginx-proxy:alpine

# Configure mysql
sudo docker run --restart=always --name=percona-mysql -d --net=host --volume=/var/lib/mysql:/var/lib/mysql -e "MYSQL_ALLOW_EMPTY_PASSWORD=yes" -e "MYSQL_DATABASE=${MYSQL_DATABASE}" -e "MYSQL_PASSWORD=${MYSQL_PASSWORD}" -e "MYSQL_USER=${MYSQL_USER}" percona:$PERCONA_VERSION
echo "Sleeping 30 seconds to give percona-mysql time to intialize"
sleep 30

# Start rancher server
sudo docker run --restart=always --name=rancher-server -d -e "CATTLE_API_HOST=http://${SERVER_IP}:${RANCHER_PORT}" -e "SERVICE_8080_NAME=rancher-server" -p $RANCHER_PORT:8080 rancher/server --db-host $SERVER_IP --db-port 3306 --db-user $MYSQL_USER --db-pass $MYSQL_PASSWORD --db-name $MYSQL_DATABASE
echo "Sleeping a minute to give rancher-server time to intialize"
sleep 60

# Get agent token and start agent
sudo curl -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 > /usr/local/bin/jq
sudo chmod +x /usr/local/bin/jq
PID=`curl -s -X GET -H "Accept: application/json" http://${SERVER_IP}:${RANCHER_PORT}/v1/projects | /usr/local/bin/jq -r '.data[0].id'`
TID=`curl -s -X POST -H "Accept: application/json" -H "Content-Type: application/json" http://${SERVER_IP}:${RANCHER_PORT}/v1/projects/$PID/registrationTokens | /usr/local/bin/jq -r '.id'`
sleep 10 # Give token time to be registered
REG_CMD=`curl -s -X GET -H "Accept: application/json" http://${SERVER_IP}:${RANCHER_PORT}/v1/projects/$PID/registrationTokens/$TID | /usr/local/bin/jq -r '.command'`
$REG_CMD -e CATTLE_AGENT_IP="${SERVER_IP}"

# Install rancher-compose
wget $RANCHER_COMPOSE_URL -O /tmp/rancher-compose.tar.gz
tar -zxvf /tmp/rancher-compose.tar.gz -C /tmp --strip-components=2
mv /tmp/rancher-compose /usr/local/bin/rancher-compose
echo "RANCHER_URL=http://${SERVER_IP}:${RANCHER_PORT}/v1/projects/${PID}/schemas" >> /etc/environment
export RANCHER_URL=http://${SERVER_IP}:${RANCHER_PORT}/v1/projects/${PID}/schemas

# Copy scripts
sudo cp /vagrant/scripts/config-rancher /usr/local/bin/config-rancher
sudo chmod 777 /usr/local/bin/*

# Echo instructions
echo "You should now be able to browse to http://127.0.0.1:${RANCHER_PORT} to use rancher."
echo "You should now be able to browse to http://127.0.0.1:8500 to use consul."
echo "Run 'vagrant ssh' to login to your sandbox."
