#!/bin/bash
cd /usr/local/pf
find . -name "switches.conf*" -exec sed -i '/^macDetection/d' '{}' \;
