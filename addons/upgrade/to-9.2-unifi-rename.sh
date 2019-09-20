#!/bin/bash

# Replace old Ubiquiti::Unifi type with renamed Ubiquiti::UniFi type
sed -i -e 's/type=Ubiquiti::Unifi/type=Ubiquiti::UniFi/g' /usr/local/pf/conf/switches.conf
