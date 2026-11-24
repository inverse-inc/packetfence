#!/bin/sh
# Prints the container tag this pipeline's packages pull (conf/build_id TAG_OR_BRANCH_NAME): the
# release tag, a feature branch's pipeline tag (its images never get a branch tag), else the branch
# slug (devel and maintenance/X.Y images get it from deploy_containers). Nothing outside CI.
set -eu

if [ -n "${CI_COMMIT_TAG:-}" ]; then
    echo "$CI_COMMIT_TAG"
    exit 0
fi
[ -n "${CI_COMMIT_REF_SLUG:-}" ] || exit 0
case "${CI_COMMIT_REF_NAME:-}" in
    devel) ;;
    maintenance/*) echo "$CI_COMMIT_REF_NAME" | grep -Eq '^maintenance/[0-9]+\.[0-9]+$' || feature=1 ;;
    *) feature=1 ;;
esac
if [ -n "${feature:-}" ]; then
    tag=$(sh "$(dirname "$0")/pipeline-image-tag.sh")
    [ -z "$tag" ] || { echo "$tag"; exit 0; }
fi
echo "$CI_COMMIT_REF_SLUG"
