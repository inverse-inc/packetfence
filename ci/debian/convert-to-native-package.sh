#!/bin/bash
set -o nounset -o pipefail -o errexit

# Switch a Debian non-native package to native package
# to simplify build using gitlab-buildpkg-tools

# change package format
sed -i 's/3.0 (quilt)/3.0 (native)/' debian/source/format

# remove revision in changelog file, prerequisite for native package
sed -i "1{s/-[0-9]*//}" debian/changelog

