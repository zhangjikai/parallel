#!/bin/sh
cd /home/zhangjikai/source/git/gitbook/zhangjk/parallel
gitbook build
cd /home/zhangjikai/source/git/github/parallel
git checkout gh-pages
yes | cp -rf /home/zhangjikai/source/git/gitbook/zhangjk/parallel/_book/* /home/zhangjikai/source/git/github/parallel/
git add -A .
git commit -m "update"
git push
git checkout master