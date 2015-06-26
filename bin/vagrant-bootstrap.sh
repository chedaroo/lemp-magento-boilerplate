#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

PROJECT_ROOT="/vagrant"
USERNAME="vagrant"
GROUP="vagrant"
RSYNC_TARGET="/home/$USERNAME"

# /tmp has to be world-writable, but sometimes isn't by default.
chmod 0777 /tmp

# Update package list
echo -e "\x1b[92m\x1b[1mUpdating package list...\x1b[0m"
apt-get update > /dev/null

# Install required Ubuntu Packages
source "$PROJECT_ROOT/bin/inc/common-install-packages.sh"

# Enable mcrypt - required by Magento
php5enmod mcrypt

# Restart Nginx and PHP
service nginx restart
service php5-fpm restart

#Set up Git interface: use colors, add "git tree" command
git config --global color.ui true
git config --global alias.tree "log --oneline --decorate --all --graph"

# Install script tools
#
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
if [ ! -d "$RSYNC_TARGET/.nvm" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling NVM for vagrant user...\x1b[0m"
  su -l $USERNAME -c "curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.25.4/install.sh | PROFILE=~/.profile bash"
  # Install latest stable version of Node.js and make default
  echo -e "\x1b[92m\x1b[1mInstalling latest stable version of Node.js...\x1b[0m"
  su -l $USERNAME -c "nvm install stable"
  su -l $USERNAME -c "nvm alias default stable"
fi

# Magento installation script, installs project in $RSYNC_TARGET
# $RSYNC_TARGET/src already exists due to rsync shared folder
chown -R $USERNAME:$GROUP $RSYNC_TARGET
sudo -u $USERNAME -H sh -c "sh $PROJECT_ROOT/bin/vagrant-magento.sh"
# make Magento directories writable as needed and add www-data user to vagrant group
chmod -R 0777 $RSYNC_TARGET/www/var $RSYNC_TARGET/www/app/etc $RSYNC_TARGET/www/media
usermod -a -G vagrant www-data
usermod -a -G www-data vagrant

# MySQL configuration, cannot be linked because MySQL refuses to load world-writable configuration
cp -f $PROJECT_ROOT/conf/my.cnf /etc/mysql/my.cnf
service mysql restart
# Allow access from host
mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'; FLUSH PRIVILEGES;"

# # Publish; Note that document root $RSYNC_TARGET/www is on the native virtual filesystem, the linked modules will be in an rsync'ed shared folder (one direction: host=>guest)
if [ -e "/etc/nginx/sites-enabled/default" ]; then
  sudo rm /etc/nginx/sites-enabled/default
fi
ln -fs $PROJECT_ROOT/conf/sites-enabled/* /etc/nginx/sites-enabled