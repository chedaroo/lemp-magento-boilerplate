#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

echo "Project Root"
read PROJECT_ROOT
USERNAME="beanstalk"
GROUP="www-data"

# /tmp has to be world-writable, but sometimes isn't by default.
chmod 0777 /tmp

# Update package list
echo -e "\x1b[92m\x1b[1mUpdating package list...\x1b[0m"
apt-get update > /dev/null

# Install required Ubuntu Packages
source "$PROJECT_ROOT/bin/inc/common-install-packages.sh"

# Secure MySQL
if [ ! -e ~/MYSQL-SECURE.flag ]; then
  source "$PROJECT_ROOT/bin/inc/linode-mysql.sh"
  touch ~/MYSQL-SECURE.flag
else
  echo "Please enter the current root MySQL password"
  read MYSQL_ROOT_PASSWORD
fi

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
  alias magerun="n98-magerun --root-dir=~/www/"
fi

# NVM - Node.js Version Manager (run 'nvm install x.xx.xx' to install required node version)
if [ ! -d "/home/beanstalk/.nvm" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling NVM for vagrant user...\x1b[0m"
  su -l $USERNAME -c "curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.25.4/install.sh | PROFILE=~/.profile bash"
  # Install latest stable version of Node.js and make default
  echo -e "\x1b[92m\x1b[1mInstalling latest stable version of Node.js...\x1b[0m"
  su -l $USERNAME -c "nvm install stable"
  su -l $USERNAME -c "nvm alias default stable"
fi

# Redis Cleanup tool and Cron tab
if [ ! -d "$PROJECT_ROOT/var/cm_redis_tools" ]; then
  # Clone tool repo and update
  cd $PROJECT_ROOT/var/
  git clone https://github.com/samm-git/cm_redis_tools.git
  cd cm_redis_tools
  git submodule update --init --recursive
  # write out current crontab
  crontab -l > mycron
  # echo new cron into cron file - Use settings in etc/local.xml <cache>
  echo "30 2 * * * /usr/bin/php $PROJECT_ROOT/var/cm_redis_tools/rediscli.php -s 127.0.0.1 -p 6379 -d 0,1" >> mycron
  # install new cron file
  crontab mycron
  rm mycron
  cd ~
fi

# Magento installation script
sudo -u $USERNAME -H PROJECT_ROOT=$PROJECT_ROOT MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD sh -c "sh $PROJECT_ROOT/bin/linode-magento.sh"

# MySQL configuration, cannot be linked because MySQL refuses to load world-writable configuration
cp -f $PROJECT_ROOT/conf/my.cnf /etc/mysql/my.cnf
service mysql restart
# Allow access from host
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'; FLUSH PRIVILEGES;"

# Remove default Nginx website conf file
if [ -e "/etc/nginx/sites-enabled/default" ]; then
  sudo rm /etc/nginx/sites-enabled/default
fi
# Symlink all Nginx website conf files
ln -fs $PROJECT_ROOT/conf/sites-enabled/* /etc/nginx/sites-enabled/
# Remove link for local Vagrant dev env Nginx conf file
rm /etc/nginx/sites-enabled/magento.local

# Restart Nginx
service nginx restart