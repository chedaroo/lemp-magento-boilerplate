#!/usr/bin/env bash

# Magento settings
DB_HOST="localhost"
DB_NAME="magento"
DB_USER="root"
DB_PASS=""
# Install Sample data (beware, takes a long time)
SAMPLE_DATA="no"
# Magento Version
MAGENTO_VERSION="magento-mirror-1.9.2.1"

# Redis Cache
CACHE_DATABASE="0"
CACHE_PERSISTENT="cache-db$CACHE_DATABASE"
# Redis Sessions
SESSION_DB="1"
SESSION_PERSISTENT="session-db$SESSION_DB"

# Install dependencies from composer.
# Extensions from Composer will be deployed after Magento has been installed
cd /vagrant
sudo composer install --prefer-dist --no-interaction --no-scripts
cd ~

# link project modman packages (src/modman imports others)
modman link ./src
modman deploy src --force

# link n98-magerun Config overides
sudo ln -fs /vagrant/conf/n98-magerun.yaml /etc/n98-magerun.yaml

# Use n98-magerun to set up Magento (database and local.xml)
# use --noDownload if Magento core is deployed with modman or composer. Test if there already is a configured Magento installation and if so skip installation
if [ ! -e "www/app/etc/local.xml" ]; then
  n98-magerun.phar install --dbHost="$DB_HOST" --dbUser="$DB_USER" --dbPass="$DB_PASS" --dbName="$DB_NAME" --installSampleData="$SAMPLE_DATA" --useDefaultConfigParams=yes --magentoVersionByName="$MAGENTO_VERSION" --installationFolder="www" --baseUrl="http://magento.local/"
fi

# #
# Configure Redis on initial installation
# #
#
# The sed commands below create the required Redis configuration files
# from default templates and symlink them to app/etc/. {{XXXXX}} represents
# placeholders in the source xml files

# Redis Backend Cache
if [ ! -e "www/app/etc/Mage_Cache_Backend_Redis.xml" ]; then
  cd /vagrant/conf
  sed -e s/"{{PERSISTENT}}"/"$CACHE_PERSISTENT"/g -e s/"{{DATABASE}}"/"$CACHE_DATABASE"/g Mage_Cache_Backend_Redis.xml > Mage_Cache_Backend_Redis.xml.vagrant
  ln -s /vagrant/conf/Mage_Cache_Backend_Redis.xml.vagrant ~/www/app/etc/Mage_Cache_Backend_Redis.xml
  cd ~
fi

# Redis Sessions
if [ ! -e "www/app/etc/Cm_RedisSession.xml" ]; then
  cd /vagrant/conf
  sed -e s/"{{PERSISTENT}}"/"$SESSION_PERSISTENT"/g -e s/"{{DB}}"/"$SESSION_DB"/g Cm_RedisSession.xml > Cm_RedisSession.xml.vagrant
  ln -s /vagrant/conf/Cm_RedisSession.xml.vagrant ~/www/app/etc/Cm_RedisSession.xml
  cd ~
  # Enable Redis sessions (disabled by default)
  n98-magerun.phar dev:module:enable Cm_RedisSession
fi

# Write permissions in media
chmod -R 0770 /home/vagrant/www/media

# Downloader no longer required really as modman should be used to install new
# extensions instead, however kept and secured by renaming
mv /home/vagrant/www/downloader /home/vagrant/www/.downloader
# Access to .downloader is resricted nginx conf. Generate password here
# to allow access magento connect downloader at http://magento.local/.downloader/
htpasswd -cb /home/vagrant/www/var/.htpasswd "$DB_USER" "$DB_PASS"

# Now after Magento has been installed, deploy all additional modules and run setup scripts
modman deploy-all --force
n98-magerun.phar sys:setup:run
n98-magerun.phar dev:symlinks --on --global

# Link local.xml from /etc, this overwrites the generated local.xml
# from the install script. If it does not exist, the generated file gets copied to /etc first
# This way you can put the devbox local.xml under version control
if [ ! -f "/vagrant/etc/local.xml" ]; then
	cp ~/www/app/etc/local.xml /vagrant/etc/local.xml
fi

ln -fs /vagrant/etc/local.xml ~/www/app/etc/local.xml

# Some devbox specific Magento settings
n98-magerun.phar config:set dev/log/active 1