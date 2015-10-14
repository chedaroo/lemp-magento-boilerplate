#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

PROJECT_ROOT="/vagrant"
USERNAME="vagrant"
GROUP="vagrant"
RSYNC_TARGET="/home/$USERNAME"

# /tmp has to be world-writable, but sometimes isn't by default.
chmod 0777 /tmp

# Update package list
echo -e "\x1b[92m\x1b[1mUpdating package list...\x1b[0m\x1b[21m"
apt-get update > /dev/null

# Install required Ubuntu Packages
source "$PROJECT_ROOT/bin/inc/common-install-packages.sh"

# Enable mcrypt - required by Magento
php5enmod mcrypt

# Restart Nginx and PHP
service nginx restart
service php5-fpm restart

# Set up Git interface: use colors, add "git tree" command
git config --global color.ui true
git config --global alias.tree "log --oneline --decorate --all --graph"

##
# Install script tools
##

# Composer
if [ ! -f "/usr/local/bin/composer" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling Composer...\x1b[0m\x1b[21m"
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
fi

# Modman
if [ ! -f "/usr/local/bin/modman" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling Modman...\x1b[0m\x1b[21m"
  curl -s -o /usr/local/bin/modman https://raw.githubusercontent.com/colinmollenhour/modman/master/modman
  chmod +x /usr/local/bin/modman
fi

# n98-magerun
if [ ! -f "/usr/local/bin/n98-magerun" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling n98-magerun...\x1b[0m\x1b[21m"
  curl -s -o /usr/local/bin/n98-magerun https://raw.githubusercontent.com/netz98/n98-magerun/master/n98-magerun.phar
  chmod +x /usr/local/bin/n98-magerun
  # Alias magerun for user
  su -l $USERNAME -c "echo \"alias magerun='n98-magerun'\" >> ~/.bash_aliases"
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

# Redis Cleanup tool and Cron tab
if [ ! -d "$PROJECT_ROOT/var/cm_redis_tools" ]; then
  echo -e "\x1b[92m\x1b[1mInstalling Redis Cleanup tool and adding cron job...\x1b[0m\x1b[21m"
  su
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
ln -fs $PROJECT_ROOT/conf/sites-enabled/local-vagrant.conf /etc/nginx/sites-enabled/local-vagrant.conf