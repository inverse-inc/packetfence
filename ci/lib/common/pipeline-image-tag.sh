#!/bin/sh
# Prints the tag this pipeline pushes its service images under until deploy_containers
# promotes them (devel and maintenance/X.Y), or nothing when they keep their branch tag.
# Must match .build_img_service_rules in .gitlab-ci.yml.
set -eu

[ -z "${CI_COMMIT_TAG:-}" ] || exit 0
[ "${BUILD_IMG_CONTAINER:-}" != no ] || exit 0
case "${CI_COMMIT_MESSAGE:-}" in *build_img_container=no*) exit 0 ;; esac
case "${CI_COMMIT_REF_NAME:-}" in
    devel) ;;
    maintenance/*)
        echo "${CI_COMMIT_REF_NAME}" | grep -Eq '^maintenance/[0-9]+\.[0-9]+$' || exit 0
        case "${CI_PIPELINE_SOURCE:-}" in web|api|schedule) ;; *) exit 0 ;; esac ;;
    *) exit 0 ;;
esac
echo "${CI_COMMIT_REF_SLUG:?}-p${CI_PIPELINE_ID:?}"
