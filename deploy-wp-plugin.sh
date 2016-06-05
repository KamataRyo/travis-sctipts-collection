#!/usr/bin/env bash

# [name] Deploy WP Plugin
# [description] Deploy a WordPress Plugin to Github and svn Plugin from Travis CI

# [Environmental Variables]
# - $WP_VERSION_TO_DEPLOY
# - $PHP_VERSION_TO_DEPLOY
# - $WP_MULTISITE_TO_DEPLOY
# - $GH_REF
# - $SVN_REF
# - $GH_TOKEN
# - $SVN_USER
# - $SVN_PASS

set -e

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
echo "Deleting remote not compiled tag '$TRAVIS_TAG'.."
git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" ":$TRAVIS_TAG" > /dev/null 2>&1
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

TEMP_DIR=$(mktemp -d)
mv ./* "${TEMP_DIR}/"

svn co "${SVN_REF}"

if [[ -d "tags/${TRAVIS_TAG}" ]]; then
    echo "'tags/${TRAVIS_TAG}' already exists."
    exit 0
fi

SVN_ROOT="$(pwd)/$(basename "$SVN_REF")"

echo "Syncing git repository to svn.."
rsync -avq --exclude=".svn" --checksum --delete "${TEMP_DIR}/" "${SVN_ROOT}/trunk/"

cd "${SVN_ROOT}/trunk"

if [[ -e ".svnignore" ]]; then
    echo "doing svn propset and setting ignore files.."
    svn propset -R svn:ignore -F .svnignore .
fi

cd "${SVN_ROOT}"

echo "Run svn add"
svn st | grep '^!' | sed -e 's/\![ ]*/svn del /g' | sh
echo "Run svn del"
svn st | grep '^?' | sed -e 's/\?[ ]*/svn add /g' | sh


svn cp -q trunk "tags/${TRAVIS_TAG}"
svn ci --quiet -m "Deploy from travis. Original commit is ${TRAVIS_COMMIT}." \
--username $SVN_USER --password $SVN_PASS --non-interactive --no-auth-cache 2>/dev/null
echo "svn commiting finished."

exit 0
