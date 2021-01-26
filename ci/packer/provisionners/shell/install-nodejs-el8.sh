#!/bin/bash
set -o nounset -o pipefail -o errexit

# Workaround for https://github.com/nodesource/distributions/issues/845

# use to download nodejs package from nodesource repo
dnf download nodejs --disablerepo=AppStream
rpm -ivh --nodeps nodejs*

