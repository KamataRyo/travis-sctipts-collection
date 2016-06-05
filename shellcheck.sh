#! /usr/bin/env bash

# [name] ShellCheck
# [description]
# [usage] bash shellcheck.sh {path}
# dependency Ubuntu

# prepare cable
apt-get install cabal
cable update

# install shellcheck
git clone https://github.com/koalaman/shellcheck.git
cd shellcheck
cable install
rm -rf shellcheck

# editting
if [[ $# -lt 1 ]]; then
    echo 'aaa'
    #statements
fi
