#!/usr/bin/env bash

# [name] Deploy WP Plugin
# [description] Deploy a WordPress Plugin to Github and svn Plugin from Travis CI

# [Environmental Variables]
# WP_VERSION_TO_DEPLOY
# PHP_VERSION_TO_DEPLOY
# WP_MULTISITE_TO_DEPLOY
# GH_REF
# SVN_REF
# GH_TOKEN
# SVN_USER
# SVN_PASS

set -e
shopt -s dotglob

# filter whether deploy or not
if ! [[ "$WP_VERSION"         == "$WP_VERSION_TO_DEPLOY" && \
        "$TRAVIS_PHP_VERSION" == "$PHP_VERSION_TO_DEPLOY" && \
        "$WP_MULTISITE"       == "$WP_MULTISITE_TO_DEPLOY" ]]; then
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

# store commit message for later process
COMMIT_MESSAGE=$(git log --format=%B -n 1 "$TRAVIS_COMMIT")

# rebuild and format repo for release
rm -rf .git
if [[ -e ".svnignore" ]]; then
    cat .svnignore > .gitignore
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
    echo "deployed on 'latest' branch, which is tested on PHP=$TRAVIS_PHP_VERSION & WP=$WP_VERSION"
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
echo "deployed as '$TRAVIS_TAG', tested on PHP=$TRAVIS_PHP_VERSION & WP=$WP_VERSION"

if [[ ("" == "$SVN_USER") || ("" == "$SVN_PASS") ]]; then
    echo "not committing to svn."
    exit 0
fi


#svn release
echo "preparing svn repo.."

if [[ -e "./.svnignore" ]]; then
    while read line
    do
        if [[ -e $line ]]; then
            rm -r "$line"
        fi
    done <.svnignore
fi
RELEASE_DIR=$(pwd)

cd "$(mktemp -d)"
svn co --quiet "${SVN_REF}"
cd "$(basename $SVN_REF)"


echo 'removing old files..'
cd trunk
ls . | grep -v -E "^.svn$" | xargs rm -r
cd ../assets
ls . | grep -v -E "^.svn$" | xargs rm -r
cd ..

ls -la

mv -r "$RELEASE_DIR"/* ./trunk

ls -la ./trunk
mv "$(find . -type f | grep -e"screenshot-[1-9][0-9]*\.[png|jpg].")" ../assets
mv "$(find . -type f | grep -e"banner-[1-9][0-9]*x[1-9][0-9]*\.[png|jpg].")" ../assets

ls -la

if [[ -e "./tags/${TRAVIS_TAG}" ]]; then
    echo "'tags/${TRAVIS_TAG}' already exists."
else
    echo 'making tag..'
    cp ./trunk "./tags/${TRAVIS_TAG}"
fi

echo 'svn committing..'
svn ci --quiet -m "Deploy from travis. Original commit is ${TRAVIS_COMMIT}." --username "$SVN_USER" --password "$SVN_PASS" --non-interactive > /dev/null 2>&1
echo "svn commiting finished."

exit 0
