#!/bin/sh
# Prints the tag this pipeline pushes its service images under: <slug>-p<pipeline> on every branch
# that builds them (devel, then maintenance/X.Y and feature branches from web/schedule), or
# nothing (release tags, cloud-nac/X.Y, no image build). Must match .build_img_service_rules in .gitlab-ci.yml.
set -eu

[ -z "${CI_COMMIT_TAG:-}" ] || exit 0
[ "${BUILD_IMG_CONTAINER:-}" != no ] || exit 0
case "${CI_COMMIT_MESSAGE:-}" in *build_img_container=no*) exit 0 ;; esac
case "${CI_COMMIT_REF_NAME:-}" in
    devel) ;;
    cloud-nac/*) exit 0 ;;  # its own image jobs keep the branch tag
    *) case "${CI_PIPELINE_SOURCE:-}" in web|schedule) ;; *) exit 0 ;; esac ;;  # 14.x builds images from web/schedule only
esac
echo "${CI_COMMIT_REF_SLUG:?}-p${CI_PIPELINE_ID:?}"
