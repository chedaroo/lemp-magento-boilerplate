#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

# /tmp has to be world-writable, but sometimes isn't by default.
chmod 0777 /tmp

# copy ssh key
# cp -r /vagrant/.ssh/* /home/vagrant/.ssh/
# chmod 0600 /home/vagrant/.ssh/*
# chown vagrant:vagrant /home/vagrant/.ssh/*

# Update package list
echo -e "\x1b[92m\x1b[1mUpdating package list...\x1b[0m"
apt-get update > /dev/null

# Install Nginx and PHP
echo -e "\x1b[92m\x1b[1mInstalling Nginx and PHP...\x1b[0m"
apt-get install -y nginx php5-fpm #> /dev/null

# Link modified Nginx conf
echo -e "\x1b[92m\x1b[1mLinking modified Nginx conf...\x1b[0m"
rm -rf /etc/nginx/nginx.conf
ln -fs /vagrant/conf/nginx.conf /etc/nginx/nginx.conf

# Install MySQL
apt-get -q -y install mysql-server mysql-client  #> /dev/null
# Required packages
apt-get install -y vim git curl #> /dev/null
apt-get install -y php5-dev php5-cli php5-mysql php5-mcrypt php5-gd php5-curl php5-tidy php-pear php-apc  #> /dev/nul

# Enable mcrypt
php5enmod mcrypt

# Restart Nginx and PHP
service nginx restart
service php5-fpm restart

#Set up Git interface: use colors, add "git tree" command
git config --global color.ui true
git config --global alias.tree "log --oneline --decorate --all --graph"

# Composer
if [ ! -f "/usr/local/bin/composer" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling Composer...\x1b[0m"
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
fi

# Modman
if [ ! -f "/usr/local/bin/modman" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling Modman...\x1b[0m"
  curl -s -o /usr/local/bin/modman https://raw.githubusercontent.com/colinmollenhour/modman/master/modman
  chmod +x /usr/local/bin/modman
fi

# n98-magerun
if [ ! -f "/usr/local/bin/n98-magerun" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling n98-magerun...\x1b[0m"
  curl -s -o /usr/local/bin/n98-magerun https://raw.githubusercontent.com/netz98/n98-magerun/master/n98-magerun.phar
  chmod +x /usr/local/bin/n98-magerun
fi

# NVM - Node.js Version Manager (run 'nvm install x.xx.xx' to install required node version)
if [ ! -d "/home/vagrant/.nvm" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling NVM for vagrant user...\x1b[0m"
  su -l vagrant -c "curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.25.4/install.sh | PROFILE=~/.profile bash"
  # Install latest stable version of Node.js and make default
  echo -e "\x1b[92m\x1b[1mInstalling latest stable version of Node.js...\x1b[0m"
  su -l vagrant -c "nvm install stable"
  su -l vagrant -c "nvm alias default stable"
fi

# # Magento installation script, installs project in /home/vagrant
# # /home/vagrant/src already exists due to rsync shared folder
# chown -R vagrant:vagrant /home/vagrant
# sudo -u vagrant -H sh -c "sh /vagrant/bin/vagrant-magento.sh"
# # make Magento directories writable as needed and add www-data user to vagrant group
# chmod -R 0777 /home/vagrant/www/var /home/vagrant/www/app/etc /home/vagrant/www/media
# usermod -a -G vagrant www-data
# usermod -a -G www-data vagrant

# # MySQL configuration, cannot be linked because MySQL refuses to load world-writable configuration
# cp -f /vagrant/conf/my.cnf /etc/mysql/my.cnf
# service mysql restart
# # Allow access from host
# mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'; FLUSH PRIVILEGES;"

# # Set locale
# ln -fs /vagrant/conf/locale /etc/default/locale

# # Publish; Note that document root /home/vagrant/www is on the native virtual filesystem, the linked modules will be in an rsync'ed shared folder (one direction: host=>guest)
# rm -rf /etc/nginx/sites-enabled
# ln -fs /vagrant/conf/sites-enabled /etc/nginx/sites-enabled

# # Restart Nginx and PHP
# service nginx restart
# service php5-fpm restart
