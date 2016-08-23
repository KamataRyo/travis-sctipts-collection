#!/usr/bin/env bash

# [description] Deploy an Electron desktop application to Github from Travis CI
# [Environmental Variables]
# NODE_VERSION_TO_DEPLOY
# GH_REF
# GH_TOKEN

set -e
shopt -s dotglob

# filter whether deploy or not
if ! [[ "$TRAVIS_NODE_VERSION" == "$NODE_VERSION_TO_DEPLOY" ]]; then
    echo "Not deploying from this matrix.";
    exit 0
elif [[ "false" != "$TRAVIS_PULL_REQUEST" ]]; then
    echo "Not deploying from pull requests."
    exit 0
elif ! [[ "master" == "$TRAVIS_BRANCH" ]]; then
    echo "Not on the 'master' branch."
    if [[ "" == "$TRAVIS_TAG" ]]; then
        echo "Not tagged."
        exit 0
    else
        echo "tagged."
    fi
fi

# store values for later process
COMMIT_MESSAGE=$(git log --format=%B -n 1 "$TRAVIS_COMMIT")
RELEASE_DIR=$(pwd)

# format the repository for release
rm -rf .git
if [[ -e ".distignore" ]]; then
    cat .distignore > .gitignore
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

# github release on 'latest' branch
if [[ "master" == "$TRAVIS_BRANCH" ]]; then
    echo "enforcing pushing to 'latest'.."
    git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:latest > /dev/null 2>&1
    echo "deployed on 'latest' branch, which is tested on NODE=$TRAVIS_NODE_VERSION"
fi

if [[  "" == "$TRAVIS_TAG" ]]; then
    echo "Not releasing without tag."
    exit 0
fi

# github tagged release.
echo "Making new tag with compiled files..."
git tag "$TRAVIS_TAG" -m "$COMMIT_MESSAGE" -m "Original commit is $TRAVIS_COMMIT."
echo "Pushing new tag '$TRAVIS_TAG'..."
git push --force --quiet --tag "https://${GH_TOKEN}@${GH_REF}" > /dev/null 2>&1
echo "deployed as '$TRAVIS_TAG', tested on NODE=$TRAVIS_NODE_VERSION"

# make sure that sensitive values are aborted
unset GH_TOKEN
exit 0
