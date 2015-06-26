#!/usr/bin/env bash
if [ ! -d "/vagrant/.modman/src" ]; then
  # Copy skin files to ems-starter
  cd /vagrant
  echo "\x1b[34m\x1b[1mCreating starter theme\x1b[0m"
  rsync --info=progress2 -a /vagrant/.modman/waterlee-boilerplate/skin/frontend/waterlee-boilerplate/default/* /vagrnnt/src/themes/custom/skin
  echo "\x1b[92m\x1b[1mFiles copied\x1b[0m"

  cd ~
  # link project modman packages (src/modman imports others)
  modman link ./src
  modman deploy src --force
fi