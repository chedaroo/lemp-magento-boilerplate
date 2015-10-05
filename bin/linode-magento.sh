#!/bin/sh

# Magento settings
DB_HOST="localhost"
echo "Database Name"
read DB_NAME
echo "Database User"
read DB_USER
DB_PASS=`echo sha256sum | base64 | head -c 12`
# Install Sample data (beware, takes a long time)
SAMPLE_DATA="no"
# Magento Version
MAGENTO_VERSION="magento-ce-1.9.1.0"
SHARED_MEDIA="/var/webroot/common/media"

# Directories
cd $PROJECT_ROOT
if [ ! -d "www" ]; then
  mkdir www
fi

# Install dependencies from composer.
# Extensions from Composer will be deployed after Magento has been installed
sudo composer install --prefer-dist --no-interaction --no-scripts

# link project modman packages (src/modman imports others)
modman link ./src
modman deploy src --force

# link n98-magerun Config overides
sudo ln -fs $PROJECT_ROOT/conf/n98-magerun.yaml /etc/n98-magerun.yaml

# Create the database and the user
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "create database if not exists $DB_NAME; grant usage on *.* to $DB_USER@localhost identified by '$DB_PASS'; grant all privileges on $DB_NAME.* to $DB_USER@localhost;"

# Use n98-magerun to set up Magento (database and local.xml)
# use --noDownload if Magento core is deployed with modman or composer. Test if there already is a configured Magento installation and if so skip installation
if [ ! -e "www/app/etc/local.xml" ]; then
  n98-magerun install --dbHost="$DB_HOST" --dbUser="$DB_USER" --dbPass="$DB_PASS" --dbName="$DB_NAME" --installSampleData="$SAMPLE_DATA" --useDefaultConfigParams=yes --magentoVersionByName="$MAGENTO_VERSION" --installationFolder="www" --baseUrl="http://magento.local/"

  # Insert Redis Backend cahe config into local.xml
  cd conf
  sed -n -i -e '/<\/global>/r Mage_Cache_Backend_Redis.xml' -e 1x -e '2,${x;p}' -e '${x;p}' $PROJECT_ROOT/www/app/etc/local.xml
  cd $PROJECT_ROOT
fi

if [ ! -d "$SHARED_MEDIA" ]; then
	sudo mv www/media $SHARED_MEDIA
fi
# Create the Media folder Symlink
sudo ln -fs $SHARED_MEDIA $PROJECT_ROOT/www/media

sudo chmod -R 0770 $SHARED_MEDIA
sudo chown -R www-data $SHARED_MEDIA

# Now after Magento has been installed, deploy all additional modules and run setup scripts
modman deploy-all --force
n98-magerun sys:setup:run
n98-magerun dev:symlinks --on --global