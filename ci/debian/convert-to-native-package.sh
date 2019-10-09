#!/bin/bash
set -o nounset -o pipefail -o errexit

# Switch a Debian non-native package to native package
# to simplify build using gitlab-buildpkg-tools

sed -i 's/3.0 (quilt)/3.0 (native)/' debian/source/format


