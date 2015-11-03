#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

clear

# Constants
USERNAME="beanstalk"
GROUP="www-data"
PROJECT_ROOT="/var/webroot"
# Environment
ENVIRONMENT=${PWD##*/}
ENVIRONMENT_ROOT="$PROJECT_ROOT/$ENVIRONMENT"
ENVIRONMENT_ETC="$ENVIRONMENT_ROOT/etc/$ENVIRONMENT"

# Test whether script is being run from ENVIRONMENT_ROOT
if [ "$PWD" != "$PROJECT_ROOT/$ENVIRONMENT" ]; then
  echo "Waring, you're running this script in the wrong directory!"
  echo "Please change your working directory to the beanstalk deployment root for this environment."
  exit
fi

# Color escape codes (for nicer output)
source "$ENVIRONMENT_ROOT/bin/inc/helpers.sh"

# Start here
printf "${FORMAT[red]}####################################${FORMAT[nf]}\n"
printf "${FORMAT[lightred]}#########${FORMAT[white]}${FORMAT[bold]} Magento Workflow ${FORMAT[nf]}${FORMAT[lightred]}#########${FORMAT[nf]}\n"
printf "${FORMAT[yellow]}####################################${FORMAT[nf]}\n"

# /tmp has to be world-writable, but sometimes isn't by default.
chmod 0777 /tmp

# Update package list
style_line cyan bold "Updating package list..."
apt-get update > /dev/null

# Install required Ubuntu Packages
source "$ENVIRONMENT_ROOT/bin/inc/common-install-packages.sh"

# Secure MySQL
style_line cyan bold "Securing MySQL..."
if [ ! -e ~/MYSQL-SECURE.flag ]; then
  source "$ENVIRONMENT_ROOT/bin/inc/linode-mysql.sh"
  touch ~/MYSQL-SECURE.flag
else
  style_message warn "MySQL has already been installed and secured on this server."
  read -s -p "Please enter the MySQL root password now: " MYSQL_ROOT_PASSWORD
  echo ""
  while ! mysql -u root -p$MYSQL_ROOT_PASSWORD  -e ";" ; do
    read -s -p "Unable to connect, check password is correct and MySQL is running: " MYSQL_ROOT_PASSWORD
    echo ""
  done

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
if [ ! -f "/usr/local/bin/n98-magerun.phar" ]; then
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
if [ ! -d "$ENVIRONMENT_ROOT/var/cm_redis_tools" ]; then
  style_line cyan bold "Installing Redis Cleanup tool and adding cron job..."
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
addCrontab "30 2 * * * /usr/bin/php $ENVIRONMENT_ROOT/var/cm_redis_tools/rediscli.php -s 127.0.0.1 -p 6379 -d 0,1"

# Magento installation script
unset MAGENTO_DOMAIN
style_line cyan bold "Magento domain..."
while [ ! $MAGENTO_DOMAIN ]; do
  read -p "Please enter the domain to be used as the base url for the '$ENVIRONMENT' installation of Magento: " MAGENTO_DOMAIN
done
sudo -u $USERNAME -H PROJECT_ROOT=$PROJECT_ROOT ENVIRONMENT=$ENVIRONMENT ENVIRONMENT_ROOT=$ENVIRONMENT_ROOT ENVIRONMENT_ETC=$ENVIRONMENT_ETC MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD MAGENTO_DOMAIN=$MAGENTO_DOMAIN sh -c "bash $ENVIRONMENT_ROOT/bin/linode-magento.sh"

# MySQL configuration, cannot be linked because MySQL refuses to load world-writable configuration
cp -f $ENVIRONMENT_ROOT/conf/my.cnf /etc/mysql/my.cnf
service mysql restart
# Allow access from host
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'; FLUSH PRIVILEGES;"

# Remove default Nginx website conf file
if [ -e "/etc/nginx/sites-enabled/default" ]; then
  sudo rm /etc/nginx/sites-enabled/default
fi

# Create Nginx conf file for Environment if it doesn't exist
if [ ! -e "$ENVIRONMENT_ROOT/conf/sites-available/$ENVIRONMENT.conf" ]; then
  sed -e s/"{{environment}}"/"$ENVIRONMENT"/g -e s/"{{domain}}"/"$MAGENTO_DOMAIN"/g $ENVIRONMENT_ROOT/conf/sites-available/nginx-template.conf > $ENVIRONMENT_ROOT/conf/sites-available/$ENVIRONMENT.conf
fi

# Symlink Nginx conf for Environment to sites-available
ln -fsv $ENVIRONMENT_ROOT/conf/sites-available/$ENVIRONMENT.conf /etc/nginx/sites-available/
# then also to sites-enabled
ln -fsv /etc/nginx/sites-available/$ENVIRONMENT.conf /etc/nginx/sites-enabled/

# Symlink environment
if [ ! -e "/etc/nginx/nginx.conf" ] ; then
  ln -fsv $ENVIRONMENT_ROOT/conf/nginx.conf /etc/nginx/nginx.conf
fi
# Restart Nginx
service nginx restart