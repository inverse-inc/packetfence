#!/usr/bin/bash

rm -rf paths/
git checkout -- paths/
rm -rf components/
git checkout -- components/
git checkout -- openapi.json
git checkout -- openapi.yaml
