#!/usr/bin/env bash

# Magento settings
printf "Database Name\n"
read DB_NAME
printf "Database User\n"
read DB_USER
DB_PASS=`echo sha256sum | base64 | head -c 12`
printf "${FORMAT[lightgreen]}$DB_PASS${FORMAT[nf]}\n"

DB_HOST="localhost"
# Install Sample data (beware, takes a long time)
SAMPLE_DATA="no"
# Magento Version
MAGENTO_VERSION="magento-mirror-1.9.2.1"
SHARED_MEDIA="$PROJECT_ROOT/common/media"

# Magento Base URL
printf "Please enter the Magento Base URL inc protocol and trailing slash (ie - http://www.domain.com/)"
read MAGENTO_BASE_URL

# Redis Cache
printf "${FORMAT[lightgreen]}Redis Backend Cache${FORMAT[nf]}\n"
printf "Please select which Redis Database you would like to use for the Backend Cache."
printf "To see a list of existing database in use start another SSH session and type 'redis-cli INFO keyspace.'"
printf "You should choose a NEW keyspace NOT in this, unless of course you wish to overite an existing one."
printf "The keyspace should be in the form of an integer (ie - 0, 1, 2, 3, etc.)\n"
printf "Redis Backend Cache Database keyspace:"
read CACHE_DATABASE
CACHE_PERSISTENT="cache-db$CACHE_DATABASE"

# Redis Sessions
printf "${FORMAT[lightgreen]}Redis Sessions${FORMAT[nf]}\n"
printf "Please select which Redis Database you would like to use for the Sessions."
printf "To see a list of existing database in use start another SSH session and type 'redis-cli INFO keyspace.'"
printf "You should choose a NEW keyspace NOT in this, unless of course you wish to overite an existing one."
printf "The keyspace should be in the form of an integer (ie - 0, 1, 2, 3, etc.)\n"
printf "Redis Sessions Database keyspace:"
read SESSION_DB
SESSION_PERSISTENT="session-db$SESSION_DB"

# Environment
ENVIRONMENT_ETC="$ENVIRONMENT_ROOT/etc/$ENVIRONMENT"
# Magento
MAGENTO_ROOT="$ENVIRONMENT_ROOT/www"
MAGENTO_ETC="$MAGENTO_ROOT/app/etc"

# Directories
cd $ENVIRONMENT_ROOT
if [ ! -d "$MAGENTO_ROOT" ]; then
  mkdir www
fi

# Install dependencies from composer.
# Extensions from Composer will be deployed after Magento has been installed
sudo composer install --prefer-dist --no-interaction --no-scripts

# link project modman packages (src/modman imports others)
modman link ./src
modman deploy src --force

# link n98-magerun Config overides
sudo ln -fs $ENVIRONMENT_ROOT/conf/n98-magerun.yaml /etc/n98-magerun.yaml

# Create the database and the user
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "create database if not exists $DB_NAME; grant usage on *.* to $DB_USER@localhost identified by '$DB_PASS'; grant all privileges on $DB_NAME.* to $DB_USER@localhost;"

# Use n98-magerun to set up Magento (database and local.xml)
# use --noDownload if Magento core is deployed with modman or composer. Test if there already is a configured Magento installation and if so skip installation
if [ ! -e "$MAGENTO_ETC/local.xml" ]; then
  n98-magerun.phar install --dbHost="$DB_HOST" --dbUser="$DB_USER" --dbPass="$DB_PASS" --dbName="$DB_NAME" --installSampleData="$SAMPLE_DATA" --useDefaultConfigParams=yes --magentoVersionByName="$MAGENTO_VERSION" --installationFolder="www" --baseUrl="$MAGENTO_BASE_URL"
fi

# Redis configuration progect directory
if [ ! -d "$ENVIRONMENT_ETC" ]; then
  mkdir $ENVIRONMENT_ETC
fi

# Redis Backend Cache create configuration xml
if [ ! -e "$ENVIRONMENT_ETC/Mage_Cache_Backend_Redis.xml" ]; then
  # Creates a new config file by copying the source xml template but
  # also replaces the {{XXXXX}} placeholders with real values
  sed -e s/"{{PERSISTENT}}"/"$CACHE_PERSISTENT"/g -e s/"{{DATABASE}}"/"$CACHE_DATABASE"/g $ENVIRONMENT_ROOT/conf/Mage_Cache_Backend_Redis.xml > $ENVIRONMENT_ETC/Mage_Cache_Backend_Redis.xml
fi

# Redis Backend Cache symlink to configuration xml
if [ ! -e "$MAGENTO_ETC/Mage_Cache_Backend_Redis.xml" ]; then
  ln -s $ENVIRONMENT_ETC/Mage_Cache_Backend_Redis.xml $MAGENTO_ETC/Mage_Cache_Backend_Redis.xml
fi

# Redis Sessions create configuration xml
if [ ! -e "$ENVIRONMENT_ETC/Cm_RedisSession.xml" ]; then
  # Creates a new config file by copying the source xml template but
  # also replaces the {{XXXXX}} placeholders with real values
  sed -e s/"{{PERSISTENT}}"/"$SESSION_PERSISTENT"/g -e s/"{{DB}}"/"$SESSION_DB"/g $ENVIRONMENT_ROOT/conf/Cm_RedisSession.xml > $ENVIRONMENT_ETC/Cm_RedisSession.xml
fi

# Redis Sessions symlink to configuration xml
if [ ! -e "$MAGENTO_ETC/Cm_RedisSession.xml" ]; then
  ln -s $ENVIRONMENT_ETC/Cm_RedisSession.xml $MAGENTO_ETC/Cm_RedisSession.xml
fi

# Enable Redis sessions (disabled by default)
n98-magerun.phar dev:module:enable Cm_RedisSession

# Move generated media dir to shared loaction if doesn't already exist
if [ ! -d "$SHARED_MEDIA" ]; then
  sudo mkdir -p $SHARED_MEDIA
	sudo mv $MAGENTO_ROOT/media/* $SHARED_MEDIA
fi

# Create the Media folder Symlink
sudo ln -fs $SHARED_MEDIA $MAGENTO_ROOT

# Sort Permissions
sudo chmod -R 0770 $SHARED_MEDIA
sudo chown -R www-data $SHARED_MEDIA

# Clear contents of old filesystem cache
rm -rf $MAGENTO_ROOT/var/cache/*

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

# Replace local.xml generated during installation with version controlled one
# fall back to vagrant and then finally use generated if fail to find
if [ ! -f "$ENVIRONMENT_ETC/local.xml" ]; then
  printf "${FORMAT[yellow]}Couldn't find $ENVIRONMENT_ETC/local.xml\nAttempting to copy $ENVIRONMENT_ROOT/etc/vagrant/local.xml an link instead.${FORMAT[nf]}"
  if [ ! -f "$ENVIRONMENT_ROOT/etc/vagrant/local.xml" ]; then
    printf "${FORMAT[yellow]}Couldn't find $ENVIRONMENT_ROOT/etc/vagrant/local.xml\nAttempting to copy $MAGENTO_ETC/local.xml to $ENVIRONMENT_ETC/local.xml and link back instead.${FORMAT[nf]}"
    # Copy generated local.xml
    cp $MAGENTO_ETC/local.xml $ENVIRONMENT_ETC/local.xml
  else
    # Copy vagrant local.xml
    cp $ENVIRONMENT_ROOT/etc/vagrant/local.xml $ENVIRONMENT_ETC/local.xml
  fi
fi
# Symlink version controlled local.xml to Magento root
ln -fs $ENVIRONMENT_ETC/local.xml $MAGENTO_ETC/local.xml