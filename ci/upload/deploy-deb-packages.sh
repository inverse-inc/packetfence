#!/bin/bash
set -o nounset -o pipefail -o errexit

DEB_UPLOAD_DIR=/root/debian/UploadQueue
DEB_RESULT_DIR=result/debian

# deploy DEB packages
for release_name in $(ls $DEB_RESULT_DIR/*); do
    changes_file=$(ls $DEB_RESULT_DIR/${release_name}/*.changes | tail -1)

    scp $DEB_RESULT_DIR/${release_name}/* $DEPLOY_HOST:$DEB_UPLOAD_DIR
    ssh $DEPLOY_HOST /usr/local/bin/ci-repo-deploy $CI_ENVIRONMENT_NAME ${release_name} $changes_file
done
