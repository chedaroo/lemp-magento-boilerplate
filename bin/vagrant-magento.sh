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

# Project
PROJECT_ROOT="/vagrant"
PROJECT_ETC="$PROJECT_ROOT/etc/vagrant"
# Magento
MAGENTO_ROOT="/home/vagrant/www"
MAGENTO_ETC="$MAGENTO_ROOT/app/etc"

# Install dependencies from composer.
# Extensions from Composer will be deployed after Magento has been installed
cd $PROJECT_ROOT
sudo composer install --prefer-dist --no-interaction --no-scripts
cd ~

# link project modman packages (src/modman imports others)
modman link ./src
modman deploy src --force

# link n98-magerun Config overides
sudo ln -fs $PROJECT_ROOT/conf/n98-magerun.yaml /etc/n98-magerun.yaml

# Use n98-magerun to set up Magento (database and local.xml)
# use --noDownload if Magento core is deployed with modman or composer. Test if there already is a configured Magento installation and if so skip installation
if [ ! -e "$MAGENTO_ETC/local.xml" ]; then
  n98-magerun.phar install --dbHost="$DB_HOST" --dbUser="$DB_USER" --dbPass="$DB_PASS" --dbName="$DB_NAME" --installSampleData="$SAMPLE_DATA" --useDefaultConfigParams=yes --magentoVersionByName="$MAGENTO_VERSION" --installationFolder="www" --baseUrl="http://magento.local/"
fi

# Redis configuration progect directory
if [ ! -d "$PROJECT_ETC" ]; then
  mkdir $PROJECT_ETC
fi

# Redis Backend Cache create configuration xml
if [ ! -e "$PROJECT_ETC/Mage_Cache_Backend_Redis.xml" ]; then
  # Creates a new config file by copying the source xml template but
  # also replaces the {{XXXXX}} placeholders with real values
  sed -e s/"{{PERSISTENT}}"/"$CACHE_PERSISTENT"/g -e s/"{{DATABASE}}"/"$CACHE_DATABASE"/g $PROJECT_ROOT/conf/Mage_Cache_Backend_Redis.xml > $PROJECT_ETC/Mage_Cache_Backend_Redis.xml
fi

# Redis Backend Cache symlink to configuration xml
if [ ! -e "$MAGENTO_ETC/Mage_Cache_Backend_Redis.xml" ]; then
  ln -s $PROJECT_ETC/Mage_Cache_Backend_Redis.xml $MAGENTO_ETC/Mage_Cache_Backend_Redis.xml
fi

# Redis Sessions create configuration xml
if [ ! -e "$PROJECT_ETC/Cm_RedisSession.xml" ]; then
  # Creates a new config file by copying the source xml template but
  # also replaces the {{XXXXX}} placeholders with real values
  sed -e s/"{{PERSISTENT}}"/"$SESSION_PERSISTENT"/g -e s/"{{DB}}"/"$SESSION_DB"/g $PROJECT_ROOT/conf/Cm_RedisSession.xml > $PROJECT_ETC/Cm_RedisSession.xml
fi

# Redis Sessions symlink to configuration xml
if [ ! -e "$MAGENTO_ETC/Cm_RedisSession.xml" ]; then
  ln -s $PROJECT_ETC/Cm_RedisSession.xml $MAGENTO_ETC/Cm_RedisSession.xml
fi

# Enable Redis sessions (disabled by default)
n98-magerun.phar dev:module:enable Cm_RedisSession

# Write permissions in media
chmod -R 0770 $MAGENTO_ROOT/media

# Downloader no longer required really as modman should be used to install new
# extensions instead, however kept and secured by renaming
mv $MAGENTO_ROOT/downloader $MAGENTO_ROOT/.downloader
# Access to .downloader is resricted nginx conf. Generate password here
# to allow access magento connect downloader at http://magento.local/.downloader/
htpasswd -cb $MAGENTO_ROOT/var/.htpasswd "$DB_USER" "$DB_PASS"

# Now after Magento has been installed, deploy all additional modules and run setup scripts
modman deploy-all --force
n98-magerun.phar sys:setup:run
n98-magerun.phar dev:symlinks --on --global

# Copy local.xml generated during installation to shared vagrant drive
# if it doesn't exist there yet so it can be placed under version control
if [ ! -f "$PROJECT_ETC/local.xml" ]; then
	cp $MAGENTO_ETC/local.xml $PROJECT_ETC/local.xml
fi
# Symlink version controlled local.xml to Magento root
ln -fs $PROJECT_ETC/local.xml $MAGENTO_ETC/local.xml

# Some devbox specific Magento settings
n98-magerun.phar config:set dev/log/active 1