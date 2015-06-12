#!/bin/sh

# Magento settings
DB_HOST="localhost"
DB_NAME="magento"
DB_USER="root"
DB_PASS=""
# Install Sample data (beware, takes a long time)
SAMPLE_DATA="no"
# Magento Version
MAGENTO_VERSION="magento-ce-1.9.1.0"

# Directories
cd ~
mkdir www

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
# CHANGE BASE URL AND MAGENTO VERSION HERE:
# use --noDownload if Magento core is deployed with modman or composer. Remove the line if there already is a configured Magento installation
n98-magerun install --dbHost="$DB_HOST" --dbUser="$DB_USER" --dbPass="$DB_PASS" --dbName="$DB_NAME" --installSampleData="$SAMPLE_DATA" --useDefaultConfigParams=yes --magentoVersionByName="$MAGENTO_VERSION" --installationFolder="www" --baseUrl="http://magento.local/"

# Write permissions in media
chmod -R 0770 /home/vagrant/www/media

# Now after Magento has been installed, deploy all additional modules and run setup scripts
modman deploy-all --force
n98-magerun sys:setup:run
n98-magerun dev:symlinks --on --global

# Link local.xml from /etc, this overwrites the generated local.xml
# from the install script. If it does not exist, the generated file gets copied to /etc first
# This way you can put the devbox local.xml under version control
if [ ! -f "/vagrant/etc/local.xml" ]; then
	cp ~/www/app/etc/local.xml /vagrant/etc/local.xml
fi

ln -fs /vagrant/etc/local.xml ~/www/app/etc/local.xml

# Some devbox specific Magento settings
n98-magerun config:set dev/log/active 1