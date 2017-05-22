#!/bin/bash

# Set variables
CWD="$(pwd)"
export DNS_IP="$(grep nameserver /etc/resolv.conf | cut -d" " -f2)"
export SERVER_IP="$(ip addr show eth0 | grep 'inet ' | cut -d"/" -f1 | awk '{ print $2}')"
CONSUL_TEMPLATE_URL="https://releases.hashicorp.com/consul-template"
CONSUL_TEMPLATE_VER="0.18.1"
export CONSUL_DOMAIN="vagrant.consul"
export CONSUL_WEB_PORT="8500"
export CONTAINER_CONF_DIR="/mnt/docker/conf"
export CONTAINER_VOL_DIR="/mnt/docker/volumes"
export DNSMASQ_USER="vagrant"
export DNSMASQ_PASSWORD="V@gr@nt"
export DNSMASQ_WEB_PORT="5380"
DOCKER_COMPOSE_VER="1.13.0"
DOCKER_PORT_RANGE="2000	2100"
DOCKER_REPO_URL="https://download.docker.com/linux/centos/docker-ce.repo"
DOCKER_VERSION="17.03.1.ce-1.el7.centos"
export MYSQL_DATABASE="rancher"
export MYSQL_PASSWORD="R@nch3r"
export MYSQL_USER="rancher"
RANCHER_COMPOSE_URL="https://releases.rancher.com/compose/v0.12.5/rancher-compose-linux-amd64-v0.12.5.tar.gz"
export RANCHER_PORT="8888"
export PERCONA_VERSION='5.7.18'

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

# Create directories
mkdir -p $CONTAINER_CONF_DIR
mkdir -p $CONTAINER_VOL_DIR

# Install docker
sudo su
sudo yum-config-manager --add-repo $DOCKER_REPO_URL
sudo yum -y install docker-ce-$DOCKER_VERSION docker-ce-selinux-$DOCKER_VERSION
sudo usermod -aG docker vagrant
sudo systemctl enable docker
sudo systemctl start docker

# Install docker-compose
sudo curl -Ss -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VER/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install rancher-compose
wget -q $RANCHER_COMPOSE_URL -O /tmp/rancher-compose.tar.gz
tar -zxvf /tmp/rancher-compose.tar.gz -C /tmp --strip-components=2
mv /tmp/rancher-compose /usr/local/bin/rancher-compose

# Configure dnsmasq
echo "log-queries" > $CONTAINER_CONF_DIR/dnsmasq.conf
echo "no-resolv" >> $CONTAINER_CONF_DIR/dnsmasq.conf
echo "server=${DNS_IP}" >> $CONTAINER_CONF_DIR/dnsmasq.conf
echo "server=/${CONSUL_DOMAIN}/${SERVER_IP}#8600" >> $CONTAINER_CONF_DIR/dnsmasq.conf

# Install consul-template
wget -q $CONSUL_TEMPLATE_URL/$CONSUL_TEMPLATE_VER/consul-template_${CONSUL_TEMPLATE_VER}_linux_amd64.zip -O /tmp/consul-template.zip
unzip /tmp/consul-template.zip -d /usr/local/bin/

# Bring up rancher via docker-compose
cd /vagrant/scripts/compose/rancher
/usr/local/bin/docker-compose up -d
cd $CWD

# Edit host DNS settings
echo "[main]" > /etc/NetworkManager/conf.d/dns.conf
echo "dns=none" >> /etc/NetworkManager/conf.d/dns.conf
systemctl restart NetworkManager.service
echo "search ${CONSUL_DOMAIN}" > /etc/resolv.conf
echo "nameserver ${SERVER_IP}" >> /etc/resolv.conf

echo "Sleeping a minute to give rancher-server time to intialize"
sleep 60

# Get agent token and start agent
sudo curl -Ss -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 > /usr/local/bin/jq
sudo chmod +x /usr/local/bin/jq
PID=`curl -Ss -X GET -H "Accept: application/json" http://${SERVER_IP}:${RANCHER_PORT}/v1/projects | /usr/local/bin/jq -r '.data[0].id'`
TID=`curl -Ss -X POST -H "Accept: application/json" -H "Content-Type: application/json" http://${SERVER_IP}:${RANCHER_PORT}/v1/projects/$PID/registrationTokens | /usr/local/bin/jq -r '.id'`
sleep 10 # Give token time to be registered
REG_CMD=`curl -Ss -X GET -H "Accept: application/json" http://${SERVER_IP}:${RANCHER_PORT}/v1/projects/$PID/registrationTokens/$TID | /usr/local/bin/jq -r '.command'`
$REG_CMD -e CATTLE_AGENT_IP="${SERVER_IP}"

# Export rancher-compose variables
echo "RANCHER_URL=http://${SERVER_IP}:${RANCHER_PORT}/v1/projects/${PID}/schemas" >> /etc/environment
export RANCHER_URL=http://${SERVER_IP}:${RANCHER_PORT}/v1/projects/${PID}/schemas

# Copy scripts
sudo chmod 777 /usr/local/bin/*

cd /vagrant/scripts/compose/default
/usr/local/bin/rancher-compose up -d
cd $CWD

# Echo instructions
echo "You should now be able to browse to http://127.0.0.1:${RANCHER_PORT} to use rancher."
echo "You should now be able to browse to http://127.0.0.1:${CONSUL_WEB_PORT} to use consul."
echo "You should now be able to browse to http://127.0.0.1:${DNSMASQ_WEB_PORT} to use dnsmasq."
echo "Run 'vagrant ssh' to login to your rancher vm."
