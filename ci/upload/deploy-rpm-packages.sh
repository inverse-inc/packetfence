#!/bin/bash
set -o nounset -o pipefail -o errexit

BASE_DIRECTORY=/var/www/repos/PacketFence

RPM_UPLOAD_DIR=$BASE_DIRECTORY/RHEL7
RPM_RESULT_DIR=public/centos

# deploy RPM packages
for release_name in $(ls $RPM_RESULT_DIR/*); do
    scp $RPM_RESULT_DIR/${release_name}/x86_64/*.rpm $DEPLOY_HOST:$RPM_UPLOAD_DIR/${CI_ENVIRONMENT_NAME}/RPMS
    ssh $DEPLOY_HOST createrepo $RPM_UPLOAD_DIR/${CI_ENVIRONMENT_NAME}/
    #ssh $DEPLOY_HOST 
done
