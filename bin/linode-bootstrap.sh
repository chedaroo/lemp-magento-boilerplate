#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

echo "Environment you wish to create - ie dev, staging, production"
read ENVIRONMENT
USERNAME="beanstalk"
GROUP="www-data"
PROJECT_ROOT="/var/webroot"
ENVIRONMENT_ROOT="$PROJECT_ROOT/$ENVIRONMENT"

# /tmp has to be world-writable, but sometimes isn't by default.
chmod 0777 /tmp

# Update package list
echo -e "\x1b[92m\x1b[1mUpdating package list...\x1b[0m"
apt-get update > /dev/null

# Install required Ubuntu Packages
source "$ENVIRONMENT_ROOT/bin/inc/common-install-packages.sh"

# Secure MySQL
if [ ! -e ~/MYSQL-SECURE.flag ]; then
  source "$ENVIRONMENT_ROOT/bin/inc/linode-mysql.sh"
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
  echo -e "\x1b[92m\x1b[1mInstalling n98-magerun...\x1b[0m\x1b[21m"
  curl -s -o /usr/local/bin/n98-magerun.phar http://files.magerun.net/n98-magerun-latest.phar
  chmod +x /usr/local/bin/n98-magerun.phar
  # Alias magerun for user
  su -l $USERNAME -c "echo \"alias magerun='n98-magerun.phar'\" >> ~/.bash_aliases"
  # Create dir for plugins
  if [ ! -d "/usr/local/share/n98-magerun/modules" ]; then
    mkdir -pv /usr/local/share/n98-magerun/modules
  fi
fi

# Magento Project Mess Detector (Magerun plugin)
if [ ! -d "/usr/local/share/n98-magerun/modules/mpmd" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling Magento Project Mess Detector (Magerun plugin)...\x1b[0m\x1b[21m"
  git clone https://github.com/AOEpeople/mpmd.git /usr/local/share/n98-magerun/modules/mpmd
fi

# Magerun Modman Command (Magerun plugin)
if [ ! -d "/usr/local/share/n98-magerun/modules/magerun-modman" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling Magerun Modman Command (Magerun plugin)...\x1b[0m\x1b[21m"
  git clone https://github.com/fruitcakestudio/magerun-modman.git /usr/local/share/n98-magerun/modules/magerun-modman
fi

# NVM - Node.js Version Manager (run 'nvm install x.xx.xx' to install required node version)
if [ ! -d "/usr/local/nvm" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling NVM...\x1b[0m\x1b[21m"
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.29.0/install.sh | NVM_DIR=/usr/local/nvm bash
  # Source NVM for all users
  NVM_DIR="/usr/local/nvm"
  SOURCE_STR="\n#Load NVM\nexport NVM_DIR=$NVM_DIR\n[ -s $NVM_DIR/nvm.sh ] && . $NVM_DIR/nvm.sh\n[[ -r $NVM_DIR/bash_completion ]] && . $NVM_DIR/bash_completion"
  su -l $USERNAME -c "printf \"$SOURCE_STR\" >> ~/.profile"
  # Change permission to allow all users to install Node versions
  chmod 0777 -R /usr/local/nvm
  # Install latest stable version of Node.js and make default
  echo -e "\x1b[92m\x1b[1mInstalling latest stable version of Node.js...\x1b[0m\x1b[21m"
  source ~/.bashrc
  su -l $USERNAME -c "nvm install stable"
  su -l $USERNAME -c "nvm alias default stable"
fi

# Redis Cleanup tool (clone)
if [ ! -d "$ENVIRONMENT_ROOT/var/cm_redis_tools" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling Redis Cleanup tool and adding cron job...\x1b[0m\x1b[21m"
  # Clone tool repo and update
  cd $ENVIRONMENT_ROOT/var/
  git clone https://github.com/samm-git/cm_redis_tools.git
  # Update tool
  cd cm_redis_tools
  git submodule update --init --recursive
  cd ~
fi

# Add Crontab for Redis clean up tool
addCrontab() {
  echo -e "\x1b[92m\x1b[1mUpdating Crontab...\x1b[0m\x1b[21m"
  # Write out current crontab
  crontab -l > mycron
  # Check for line and append if not found
  grep -Fq "$1" mycron || echo "$1" >> mycron
  # Install modified crontab
  crontab mycron
  # Clean up temporary file
  rm mycron
}
# add to crontab if doesn't already exist - Uses confin settings in app/etc/ (<cache>)
addCrontab "30 2 * * * /usr/bin/php $ENVIRONMENT_ROOT/var/cm_redis_tools/rediscli.php -s 127.0.0.1 -p 6379 -d 0,1"

# Magento installation script
sudo -u $USERNAME -H ENVIRONMENT=$ENVIRONMENT PROJECT_ROOT=$PROJECT_ROOT ENVIRONMENT_ROOT=$ENVIRONMENT_ROOT MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD sh -c "sh $ENVIRONMENT_ROOT/bin/linode-magento.sh"

# MySQL configuration, cannot be linked because MySQL refuses to load world-writable configuration
cp -f $ENVIRONMENT_ROOT/conf/my.cnf /etc/mysql/my.cnf
service mysql restart
# Allow access from host
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'; FLUSH PRIVILEGES;"

# Remove default Nginx website conf file
if [ -e "/etc/nginx/sites-enabled/default" ]; then
  sudo rm /etc/nginx/sites-enabled/default
fi
# Symlink all Nginx website conf files
ln -fs $ENVIRONMENT_ROOT/conf/sites-enabled/* /etc/nginx/sites-enabled/
# Remove link for local Vagrant dev env Nginx conf file
rm /etc/nginx/sites-enabled/local-vagrant.conf

# Restart Nginx
service nginx restart