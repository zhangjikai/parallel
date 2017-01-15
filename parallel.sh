#!/bin/sh
cd /home/zhangjikai/source/git/github/parallel
git checkout master
git pull
git checkout gh-pages
git pull
cd /home/zhangjikai/source/git/gitbook/zhangjk/parallel
gitbook build
yes | cp -rf /home/zhangjikai/source/git/gitbook/zhangjk/parallel/_book/* /home/zhangjikai/source/git/github/parallel/
cd /home/zhangjikai/source/git/github/parallel
git checkout gh-pages
git add -A .
git commit -m "update"
git push
git checkout master
rsync -av --exclude='_book' --exclude='.git' --exclude='node_modules' -exclude='README.md' /home/zhangjikai/source/git/gitbook/zhangjk/parallel/ /home/zhangjikai/source/git/github/parallel/
git add -A .
git commit -m "update"
