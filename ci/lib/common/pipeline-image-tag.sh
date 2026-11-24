#!/bin/sh
# Prints the tag this pipeline pushes its service images under: <slug>-p<pipeline> on every branch
# that builds them (devel, then maintenance/X.Y and feature branches from web/API/schedule), or
# nothing (release tags, cloud-nac/X.Y, no image build). Must match .build_img_service_rules in .gitlab-ci.yml.
set -eu

[ -z "${CI_COMMIT_TAG:-}" ] || exit 0
# Requested tests build the images whatever BUILD_IMG_CONTAINER says (as .gitlab-ci.yml).
if ! { [ "${TEST:-}" = yes ] || case "${CI_COMMIT_MESSAGE:-}" in *test=yes*) true ;; *) false ;; esac; }; then
    [ "${BUILD_IMG_CONTAINER:-}" != no ] || exit 0
    case "${CI_COMMIT_MESSAGE:-}" in *build_img_container=no*) exit 0 ;; esac
fi
case "${CI_COMMIT_REF_NAME:-}" in
    devel) ;;
    cloud-nac/*) exit 0 ;;  # its own image jobs keep the branch tag
    *) case "${CI_PIPELINE_SOURCE:-}" in web|api|schedule) ;; *) exit 0 ;; esac ;;
esac
echo "${CI_COMMIT_REF_SLUG:?}-p${CI_PIPELINE_ID:?}"
