#!/usr/bin/env bash

# Helper functions
source "$ENVIRONMENT_ROOT/bin/inc/helpers.sh"
source "$ENVIRONMENT_ROOT/bin/inc/redis-select-db.sh"

# Environment
ENVIRONMENT_ETC="$ENVIRONMENT_ROOT/etc/$ENVIRONMENT"

# Magento
MAGENTO_ROOT="$ENVIRONMENT_ROOT/www"
MAGENTO_ETC="$MAGENTO_ROOT/app/etc"

# Shared with other environments
SHARED_MEDIA="$PROJECT_ROOT/common/media"

# FLAGS
MAGENTO_INSTALLED=$(test_file -e $MAGENTO_ETC/local.xml)
BACKEND_CACHE_CONFIGURED=$(test_file -e $ENVIRONMENT_ETC/Mage_Cache_Backend_Redis.xml)
BACKEND_CACHE_LINKED=$(test_file -e $MAGENTO_ETC/Mage_Cache_Backend_Redis.xml)
SESSIONS_CONFIGURED=$(test_file -e $ENVIRONMENT_ETC/Cm_RedisSession.xml)
SESSIONS_LINKED=$(test_file -e $MAGENTO_ETC/Cm_RedisSession.xml)

# if [ ! MAGENTO_INSTALLED ]; then

  unset DB_NAME
  unset DB_USER
  unset DB_PASS

  # Get list of existing MySQL Databases
  list_mysql_databases=$(mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)
  # Put list in array
  read -a mysql_databases <<<$list_mysql_databases

  # Configuration for the installer
  SAMPLE_DATA="no"
  DB_HOST="localhost"
  MAGENTO_VERSION="magento-mirror-1.9.2.1"

  # Request / generate database configuration
  style_line "Please enter the name of the database you would like to use for this installation."
  style_line "This needs to be prefixed with 'magento_'"
  style_message hint "A good name would be something like 'magento_$ENVIRONMENT'"

  while [[ "${DB_NAME}" != magento_* ]]; do
    # Request database name
    read DB_NAME
    # Check database name doesn't already exist
    if in_array mysql_databases "${DB_NAME}"; then
      style_message error "The database '${DB_NAME}' already exists and so can't be used :("
      unset DB_NAME
    # Check database name is valid (starts with 'magento_')
    elif [[ "${DB_NAME}" != magento_* ]]; then
      style_message error "The database name must start with 'magento_'"
      unset DB_NAME
    # Check database name is Alpha Numeric and underscore only
    elif [[ "${DB_NAME}" == "^[a-zA-Z0-9_]*$" ]]; then
      style_message error "The database name must be Alpha Numeric, with the exception of '_'"
      unset DB_NAME
    # All is good, accepted DB_NAME
    else
      # Use DB_NAME as DB_USER
      DB_USER="${DB_NAME}"
      # Generated password will contain at least:
      #   1 Special
      #   1 Number
      #   1 Lower Alpha
      #   1 Upper Alpha
      # The password will be between 16 and 23 characters long
      # http://stackoverflow.com/questions/26665389/random-password-generator-bash#answer-26665585
      choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
      DB_PASS=$({
          choose '!@#$%^\&'
          choose '0123456789'
          choose 'abcdefghijklmnopqrstuvwxyz'
          choose 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
          for i in $( seq 1 $(( 12 + RANDOM % 8 )) ); do
            choose '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
          done
      } | sort -R | awk '{printf "%s",$1}')
    fi
  done

  # Magento database details
  style_line lightgreen "Magento Database details..."
  style_config "Database Name" $DB_NAME
  style_config "Database User" $DB_USER
  style_config "Database Password" $DB_PASS

  # Magento Base URL
  printf "Please enter the Magento Base URL inc protocol and trailing slash (ie - http://www.domain.com/):\n"
  read MAGENTO_BASE_URL
# fi
exit

# Redis Cache
printf "${FORMAT[lightgreen]}Redis Backend Cache${FORMAT[nf]}\n"
printf "Please select which Redis Database you would like to use for the Backend Cache.\n"
printf "To see a list of existing database in use start another SSH session and type 'redis-cli INFO keyspace.'\n"
printf "You should choose a NEW keyspace NOT in this, unless of course you wish to overite an existing one.\n"
printf "The keyspace should be in the form of an integer (ie - 0, 1, 2, 3, etc.)\n"
printf "Redis Backend Cache Database keyspace:\n"
redis_select_db
CACHE_DATABASE="${get_db}"
CACHE_PERSISTENT="cache-db$CACHE_DATABASE"

# Redis Sessions
printf "${FORMAT[lightgreen]}Redis Sessions${FORMAT[nf]}\n"
printf "Please select which Redis Database you would like to use for the Sessions.\n"
printf "To see a list of existing database in use start another SSH session and type 'redis-cli INFO keyspace.'\n"
printf "You should choose a NEW keyspace NOT in this, unless of course you wish to overite an existing one.\n"
printf "The keyspace should be in the form of an integer (ie - 0, 1, 2, 3, etc.)\n"
printf "Redis Sessions Database keyspace:\n"
redis_select_db
SESSION_DB="${get_db}"
SESSION_PERSISTENT="session-db$SESSION_DB"

# Go to deployment root
cd $ENVIRONMENT_ROOT

# Create Magento installation root
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
sudo ln -fsv $ENVIRONMENT_ROOT/conf/n98-magerun.yaml /etc/n98-magerun.yaml

# Create the database and the user
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "create database if not exists $DB_NAME; grant usage on *.* to $DB_USER@localhost identified by '$DB_PASS'; grant all privileges on $DB_NAME.* to $DB_USER@localhost;"

# Use n98-magerun to set up Magento (database and local.xml)
# use --noDownload if Magento core is deployed with modman or composer. Test if there already is a configured Magento installation and if so skip installation
if [ ! $MAGENTO_INSTALLED ]; then
  n98-magerun.phar install --dbHost="$DB_HOST" --dbUser="$DB_USER" --dbPass="$DB_PASS" --dbName="$DB_NAME" --installSampleData="$SAMPLE_DATA" --useDefaultConfigParams=yes --magentoVersionByName="$MAGENTO_VERSION" --installationFolder="www" --baseUrl="$MAGENTO_BASE_URL"
fi

# Create environment etc directory
if [ ! -d "$ENVIRONMENT_ETC" ]; then
  mkdir $ENVIRONMENT_ETC
fi

# Redis Backend Cache create configuration xml
if [ ! $BACKEND_CACHE_CONFIGURED ]; then
  # Creates a new config file by copying the source xml template but
  # also replaces the {{XXXXX}} placeholders with real values
  sed -e s/"{{PERSISTENT}}"/"$CACHE_PERSISTENT"/g -e s/"{{DATABASE}}"/"$CACHE_DATABASE"/g $ENVIRONMENT_ROOT/conf/Mage_Cache_Backend_Redis.xml > $ENVIRONMENT_ETC/Mage_Cache_Backend_Redis.xml
fi

# Redis Backend Cache symlink to configuration xml
if [ ! $BACKEND_CACHE_LINKED ]; then
  ln -sv $ENVIRONMENT_ETC/Mage_Cache_Backend_Redis.xml $MAGENTO_ETC/Mage_Cache_Backend_Redis.xml
fi

# Redis Sessions create configuration xml
if [ ! $SESSIONS_CONIGURED ]; then
  # Creates a new config file by copying the source xml template but
  # also replaces the {{XXXXX}} placeholders with real values
  sed -e s/"{{PERSISTENT}}"/"$SESSION_PERSISTENT"/g -e s/"{{DB}}"/"$SESSION_DB"/g $ENVIRONMENT_ROOT/conf/Cm_RedisSession.xml > $ENVIRONMENT_ETC/Cm_RedisSession.xml
fi

# Redis Sessions symlink to configuration xml
if [ ! $SESSIONS_LINKED ]; then
  ln -sv $ENVIRONMENT_ETC/Cm_RedisSession.xml $MAGENTO_ETC/Cm_RedisSession.xml
fi

# Enable Redis sessions (disabled by default)
n98-magerun.phar dev:module:enable Cm_RedisSession

# Move generated media dir to shared loaction if doesn't already exist
if [ ! -d "$SHARED_MEDIA" ]; then
  sudo mkdir -p $SHARED_MEDIA
	sudo mv $MAGENTO_ROOT/media/* $SHARED_MEDIA
fi

# Create the Media folder Symlink
sudo ln -fsv $SHARED_MEDIA $MAGENTO_ROOT

# Sort Permissions
sudo chmod -R 0770 $SHARED_MEDIA
sudo chown -R www-data $SHARED_MEDIA

# Clear contents of old filesystem cache
rm -rfv $MAGENTO_ROOT/var/cache/*

# Downloader no longer required really as modman should be used to install new
# extensions instead, however kept and secured by renaming
mv -v $MAGENTO_ROOT/downloader $MAGENTO_ROOT/.downloader
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
  printf "${FORMAT[yellow]}Couldn't find $ENVIRONMENT_ETC/local.xml\nAttempting to copy $ENVIRONMENT_ROOT/etc/vagrant/local.xml an link instead.${FORMAT[nf]}\n"
  if [ ! -f "$ENVIRONMENT_ROOT/etc/vagrant/local.xml" ]; then
    printf "${FORMAT[yellow]}Couldn't find $ENVIRONMENT_ROOT/etc/vagrant/local.xml\nAttempting to copy $MAGENTO_ETC/local.xml to $ENVIRONMENT_ETC/local.xml and link back instead.${FORMAT[nf]}\n"
    # Copy generated local.xml
    cp $MAGENTO_ETC/local.xml $ENVIRONMENT_ETC/local.xml
  else
    # Copy vagrant local.xml
    cp $ENVIRONMENT_ROOT/etc/vagrant/local.xml $ENVIRONMENT_ETC/local.xml
  fi
fi
# Symlink version controlled local.xml to Magento root
ln -fsv $ENVIRONMENT_ETC/local.xml $MAGENTO_ETC/local.xml