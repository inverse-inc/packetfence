#!/bin/sh -e

git diff github-inverse/devel lib/ > sdn.patch
git diff github-inverse/devel sbin/ >> sdn.patch
