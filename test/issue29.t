#!/usr/bin/env bash

set -e

source test/setup

use Test::More

# if [ "$1" == ReRun ]; then
#   set -x
# else
#   "$0" ReRun 2>&1 | tee log
#   exit 0
# fi

cd "$TMP"

# Make 3 new repos:
(
  mkdir share main1 main2
  git init share
  git init main1
  git init main2
) > /dev/null

# Add an empty 'readme' to the share repo:
(
  cd share
  touch readme
  git add readme
  git commit -m "Initial share"
  # To push to share later we must not have working copy on master branch:
  git checkout -b temp
) &> /dev/null

# `subrepo clone` the share repo into main1:
(
  cd main1
  touch main1
  git add main1
  git commit -m "Initial"
  git subrepo clone ../share share -b master
) > /dev/null

# `subrepo clone` the share repo into main2:
(
  cd main2
  touch main2
  git add main2
  git commit -m "Initial"
  git subrepo clone ../share share -b master
) > /dev/null

# Make a change to the main1 subrepo and push it:
msg_main1="main1 initial add to subrepo"
(
  set -x

  cd main1
  echo "$msg_main1" >> share/readme
  git add share/readme
  git commit -m "$msg_main1"
  git subrepo branch -F share
  git rebase refs/subrepo/share/upstream subrepo/share
  git checkout master
  git subrepo push share
  git subrepo clean --all --force
) &> /dev/null

# Pull in the subrepo changes from above into main2.
# Make a local change to the main2 subrepo and push it:
msg_main2="main2 initial add to subrepo"
(
  set -x

  cd main2
  git subrepo pull share
  echo "$msg_main2" >> share/readme
  git add share/readme
  git commit -m "$msg_main2"

  # Prepare for a by-hand merge
  git subrepo branch -f -F share
  git rebase refs/subrepo/share/upstream subrepo/share || true

  # We have a rebase conflict. Resolve it:
  git checkout --theirs readme
  git add readme
  git rebase --continue
  git checkout master

  git subrepo push share
) &> /dev/null

# Go back into main1 and pull the subrepo updates:
(
  set -x

  cd main1
  # git subrepo pull share

  # Prepare for a by-hand merge
  git subrepo branch -f -F share
  git rebase refs/subrepo/share/upstream subrepo/share || true

  # We have a rebase conflict. Resolve it:
  git rebase --skip
  git checkout master
  git subrepo commit share
) &> /dev/null

# The readme file should have both changes:
is "$(cat main1/share/readme)" \
  "$msg_main1"$'\n'"$msg_main2" \
  "readme has both commits"

done_testing

teardown
