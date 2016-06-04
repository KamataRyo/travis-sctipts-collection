#! /usr/bin/env bash

# [name] Travis Encrypt WP
# [description] Encrypt GH_TOKEN, SVN_USER, SVN_PASS at once
# [usage] travis-encrypt-wp {GH_TOKEN} {SVN_USER}
# [dependency] Run on Mac. It uses keychain to find


service="<https://plugins.svn.wordpress.org:443> Use your WordPress.org login"
GH_TOKEN=$1
SVN_USER=$2
SVN_PASS=`security find-generic-password -wgs "$service" -a$SVN_USER`

travis encrypt GH_TOKEN="$GH_TOKEN" SVN_USER="$SVN_USER" SVN_PASS="$SVN_PASS"
