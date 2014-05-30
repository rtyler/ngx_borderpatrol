#!/bin/sh

if [ "$(ls -A /etc/borderpatrol/sites-enabled)" ]; then
  echo "/etc/borderpatrol/sites-enabled is not empty; skipping symlinking of default conf file"
else
  ln -s /etc/borderpatrol/sites-available/default.conf /etc/borderpatrol/sites-enabled/default.conf || true
fi
