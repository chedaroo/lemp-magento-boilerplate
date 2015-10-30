#!/usr/bin/env bash

# Install Nginx and PHP
style_line cyan bold "Installing Nginx and PHP..."
apt-get install -y nginx php5-fpm > /dev/null

# Link modified Nginx conf
style_line cyan bold "Linking modified Nginx conf..."
rm -rf /etc/nginx/nginx.conf
ln -fs $PROJECT_ROOT/conf/nginx.conf /etc/nginx/nginx.conf

# Install MySQL
style_line cyan bold "Installing MySQL..."
apt-get -q -y install mysql-server mysql-client  > /dev/null

# Install additional required packages
style_line cyan bold "Installing PHP and additional packages..."
apt-get install -y vim git curl > /dev/null
apt-get install -y redis-server mini-httpd php5-dev php5-cli php5-mysql php5-mcrypt php5-gd php5-curl php5-tidy php-pear php-apc  > /dev/null

# Install Redis server for Backend and Session caching
style_line cyan bold "Installing Redis..."
apt-get install -y redis-server  > /dev/null
pecl install redis > /dev/null
echo "extension=redis.so" > /etc/php5/mods-available/redis.ini
php5enmod redis

# Install PHPMyAdmin
style_line cyan bold "Installing PHPMyAdmin..."
apt-get install -y phpmyadmin > /dev/null
if [ ! -e "$RSYNC_TARGET/www/phpmyadmin" ]; then
  # Create symbolic link from fileshare, composer will need this to validate magento installation
  ln -s /usr/share/phpmyadmin/ $RSYNC_TARGET/www
  # Create config backup
  cp /etc/phpmyadmin/config.inc.php /etc/phpmyadmin/config.old.inc.php
  # Allow no password for root
  PMA_AllowNoPassword_Find="AllowNoPassword"
  PMA_AllowNoPassword_Replace="\$cfg['Servers'][\$i]['AllowNoPassword'] = true;"
  sed -i "s/.*$PMA_AllowNoPassword_Find.*/$PMA_AllowNoPassword_Replace/" /etc/phpmyadmin/config.inc.php # Find in line and replace whole line
fi