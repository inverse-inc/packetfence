#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd /usr/local/pf/lib/perl_modules
tar cvfz $SCRIPT_DIR/cpan_perl_module_without_all_path.tar.gz ./
cp $SCRIPT_DIR/cpan_perl_module_without_all_path.tar.gz $SCRIPT_DIR/rhel8/SOURCES/
