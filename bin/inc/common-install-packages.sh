#!/usr/bin/env bash

# Install Nginx and PHP
echo -e "\x1b[92m\x1b[1mInstalling Nginx and PHP...\x1b[0m"
apt-get install -y nginx php5-fpm #> /dev/null

# Link modified Nginx conf
echo -e "\x1b[92m\x1b[1mLinking modified Nginx conf...\x1b[0m"
rm -rf /etc/nginx/nginx.conf
ln -fs $PROJECT_ROOT/conf/nginx.conf /etc/nginx/nginx.conf

# Install MySQL
echo -e "\x1b[92m\x1b[1mInstalling MySQL...\x1b[0m"
apt-get -q -y install mysql-server mysql-client  #> /dev/null

# Install additional required packages
apt-get install -y vim git curl #> /dev/null
apt-get install -y redis-server php5-dev php5-cli php5-mysql php5-mcrypt php5-gd php5-curl php5-tidy php-pear php-apc  #> /dev/nul

# Install Redis server for Backend and Session caching
echo -e "\x1b[92m\x1b[1mInstalling Redis...\x1b[0m"
apt-get install -y redis-server  #> /dev/null
pecl install redis
echo "extension=redis.so" > /etc/php5/mods-available/redis.ini
php5enmod redis