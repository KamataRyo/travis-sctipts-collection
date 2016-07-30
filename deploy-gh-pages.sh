#!/usr/bin/env bash

# [description] Deploy a GH-pages
# [Environmental Variables]
# NODE_VERSION_TO_DEPLOY
# GH_REF
# GH_TOKEN

set -e
shopt -s dotglob

# filter whether deploy or not
if ! [[ "$TRAVIS_NODE_VERSION" == "$NODE_VERSION_TO_DEPLOY" ]]; then
    echo "Not deploying from this job.";
    exit 0
elif [[ "false" != "$TRAVIS_PULL_REQUEST" ]]; then
    echo "Not deploying from pull requests."
    exit 0
elif ! [[ "master" == "$TRAVIS_BRANCH" ]]; then
    exit 0
fi

# format the repository for release
rm -rf .git
if [[ -e ".deployignore" ]]; then
    cat .deployignore > .gitignore
fi

# prevent loop
if [[ -e ".travis.yml" ]]; then
    rm .travis.yml
fi

git init
git config user.name "kamataryo"
git config user.email "kamataryo@travis-ci.org"
git add .
git commit --quiet -m "Deploy from travis." -m "Original commit is $TRAVIS_COMMIT."

# github release on 'gh-pages' branch
if [[ "master" == "$TRAVIS_BRANCH" ]]; then
    echo "enforcing pushing to 'gh-pages'.."
    git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:gh-pages > /dev/null 2>&1
    echo "deployed on 'gh-pages' branch, which is tested on PHP=$TRAVIS_PHP_VERSION & WP=$WP_VERSION"
fi

if [[  "" == "$TRAVIS_TAG" ]]; then
    echo "Not releasing without tag."
    exit 0
fi
