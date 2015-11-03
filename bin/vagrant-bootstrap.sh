#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive


PROJECT_ROOT="/vagrant"
USERNAME="vagrant"
GROUP="vagrant"
RSYNC_TARGET="/home/$USERNAME"

# Helper functions
source "$PROJECT_ROOT/bin/inc/helpers.sh"

# /tmp has to be world-writable, but sometimes isn't by default.
chmod 0777 /tmp

# Create webroot
if [ ! -d "$RSYNC_TARGET/www" ]; then
  mkdir www
  # Create symbolic link from fileshare, composer will need this to validate magento installation
  ln -sv $RSYNC_TARGET/www $PROJECT_ROOT/www
fi

# Update package list
style_line cyan bold "Updating package list..."
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
  style_line cyan bold "Installing Composer..."
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
fi

# Modman
if [ ! -f "/usr/local/bin/modman" ]; then
  style_line cyan bold "Installing Modman..."
  curl -s -o /usr/local/bin/modman https://raw.githubusercontent.com/colinmollenhour/modman/master/modman
  chmod +x /usr/local/bin/modman
fi

# n98-magerun
if [ ! -f "/usr/local/bin/n98-magerun" ]; then
  style_line cyan bold "Installing n98-magerun..."
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
  style_line cyan bold "Installing Magento Project Mess Detector (Magerun plugin)..."
  git clone https://github.com/AOEpeople/mpmd.git /usr/local/share/n98-magerun/modules/mpmd
fi

# Magerun Modman Command (Magerun plugin)
if [ ! -d "/usr/local/share/n98-magerun/modules/magerun-modman" ]; then
  style_line cyan bold "Installing Magerun Modman Command (Magerun plugin)..."
  git clone https://github.com/fruitcakestudio/magerun-modman.git /usr/local/share/n98-magerun/modules/magerun-modman
fi

# NVM - Node.js Version Manager (run 'nvm install x.xx.xx' to install required node version)
if [ ! -d "/usr/local/nvm" ]; then
  style_line cyan bold "Installing NVM..."
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.29.0/install.sh | NVM_DIR=/usr/local/nvm bash
  # Source NVM for all users
  NVM_DIR="/usr/local/nvm"
  SOURCE_STR="\n#Load NVM\nexport NVM_DIR=$NVM_DIR\n[ -s $NVM_DIR/nvm.sh ] && . $NVM_DIR/nvm.sh\n[[ -r $NVM_DIR/bash_completion ]] && . $NVM_DIR/bash_completion"
  su -l $USERNAME -c "printf \"$SOURCE_STR\" >> ~/.profile"
  # Change permission to allow all users to install Node versions
  chmod 0777 -R /usr/local/nvm
  # Install latest stable version of Node.js and make default
  style_line cyan bold "Installing latest stable version of Node.js..."
  source ~/.bashrc
  su -l $USERNAME -c "nvm install stable"
  su -l $USERNAME -c "nvm alias default stable"
fi

# Redis Cleanup tool (clone)
if [ ! -d "$PROJECT_ROOT/var/cm_redis_tools" ]; then
  style_line cyan bold "Installing Redis Cleanup tool and adding cron job..."
  su
  # Clone tool repo and update
  cd $PROJECT_ROOT/var/
  git clone https://github.com/samm-git/cm_redis_tools.git
  # Update tool
  cd cm_redis_tools
  git submodule update --init --recursive
  cd ~
fi

# Add Crontab for Redis clean up tool
addCrontab() {
  style_line cyan bold "Updating Crontab..."
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
addCrontab "30 2 * * * /usr/bin/php $PROJECT_ROOT/var/cm_redis_tools/rediscli.php -s 127.0.0.1 -p 6379 -d 0,1"

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
ln -fsv $PROJECT_ROOT/conf/sites-enabled/local-vagrant.conf /etc/nginx/sites-enabled/local-vagrant.conf