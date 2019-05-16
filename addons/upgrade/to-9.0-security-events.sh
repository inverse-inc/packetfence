#!/bin/bash

SED_BAK_SUFFIX=".pre-9.0-security-events-script"

echo "Moving violations.conf.rpmsave to security_events.conf"
yes | mv /usr/local/pf/conf/violations.conf.rpmsave /usr/local/pf/conf/security_events.conf

echo "Renaming values in adminroles.conf"
sed -i$SED_BAK_SUFFIX 's/VIOLATIONS_/SECURITY_EVENTS_/g' /usr/local/pf/conf/adminroles.conf

echo "Renaming violation_maintenance task in pfmon"
sed -i$SED_BAK_SUFFIX 's/violation_maintenance/security_event_maintenance/g' /usr/local/pf/conf/pfmon.conf

echo "Renaming violations related data in filter engines files (VLAN and RADIUS filters along with WMI rules)"
for F in /usr/local/pf/conf/radius_filters.conf /usr/local/pf/conf/vlan_filters.conf /usr/local/pf/conf/wmi.conf; do
  sed -i$SED_BAK_SUFFIX 's/^filter\s*=\s*violation/filter = security_event/g' $F
  sed -i$SED_BAK_SUFFIX 's/trigger_violation/trigger_security_event/g' $F
  sed -i$SED_BAK_SUFFIX 's/ViolationRole/IsolationRole/g' $F
done

echo "Renaming violations related data in report.conf"
sed -i$SED_BAK_SUFFIX 's/violation\./security_event\./g' /usr/local/pf/conf/report.conf
sed -i$SED_BAK_SUFFIX 's/=violation/=security_event/g' /usr/local/pf/conf/report.conf
sed -i$SED_BAK_SUFFIX 's/violation/security event/g' /usr/local/pf/conf/report.conf
sed -i$SED_BAK_SUFFIX 's/Violation/Security Event/g' /usr/local/pf/conf/report.conf
sed -i$SED_BAK_SUFFIX 's/vid/security_event_id/g' /usr/local/pf/conf/report.conf

echo "Renaming violations related data in stats.conf"
sed -i$SED_BAK_SUFFIX 's/source\.packetfence\.violations/source.packetfence.security_events/g' /usr/local/pf/conf/stats.conf
sed -i$SED_BAK_SUFFIX 's/from violation/from security_event/g' /usr/local/pf/conf/stats.conf

echo "Completed renaming"
