import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const pfReportFields = {
  mac: {
    value: 'mac',
    text: i18n.t('MAC Address'),
    types: [conditionType.SUBSTRING]
  }
}

export const pfReportColumns = {
  acctinput: {
    key: 'acctinput',
    label: i18n.t('Bytes In'),
    sortable: true,
    visible: true
  },
  acctinputoctets: {
    key: 'acctinputoctets',
    label: i18n.t('Octets In'),
    sortable: true,
    visible: true
  },
  acctoutput: {
    key: 'acctoutput',
    label: i18n.t('Bytes Out'),
    sortable: true,
    visible: true
  },
  acctoutputoctets: {
    key: 'acctoutputoctets',
    label: i18n.t('Octets Out'),
    sortable: true,
    visible: true
  },
  accttotal: {
    key: 'accttotal',
    label: i18n.t('Bytes Total'),
    sortable: true,
    visible: true
  },
  accttotaloctets: {
    key: 'accttotaloctets',
    label: i18n.t('Octets Total'),
    sortable: true,
    visible: true
  },
  autoreg: {
    key: 'autoreg',
    label: i18n.t('Auto Registration'),
    sortable: true,
    visible: true
  },
  bandwidth_balance: {
    key: 'bandwidth_balance',
    label: i18n.t('Bandwidth Balance'),
    sortable: true,
    visible: true
  },
  bypass_role_id: {
    key: 'bypass_role_id',
    label: i18n.t('Bypass Role'),
    sortable: true,
    visible: true
  },
  bypass_vlan: {
    key: 'bypass_vlan',
    label: i18n.t('Bypass VLAN'),
    sortable: true,
    visible: true
  },
  callingstationid: {
    key: 'callingstationid',
    label: i18n.t('Calling Station ID'),
    sortable: true,
    visible: true
  },
  category_id: {
    key: 'category_id',
    label: i18n.t('Role'),
    sortable: true,
    visible: true
  },
  computer_name: {
    key: 'computer_name',
    label: i18n.t('Computername'),
    sortable: true,
    visible: true
  },
  connection_type: {
    key: 'connection_type',
    label: i18n.t('Connection Type'),
    sortable: true,
    visible: true
  },
  connections: {
    key: 'connections',
    label: i18n.t('Connections'),
    sortable: true,
    visible: true
  },
  computername: {
    key: 'computername',
    label: i18n.t('Computername'),
    sortable: true,
    visible: true
  },
  count: {
    key: 'count',
    label: i18n.t('Count'),
    sortable: true,
    visible: true
  },
  description: {
    key: 'description',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  detect_date: {
    key: 'detect_date',
    label: i18n.t('Detect Date'),
    sortable: true,
    visible: true
  },
  device_class: {
    key: 'device_class',
    label: i18n.t('Device Class'),
    sortable: true,
    visible: true
  },
  device_manufacturer: {
    key: 'device_manufacturer',
    label: i18n.t('Device Manufacturer'),
    sortable: true,
    visible: true
  },
  device_score: {
    key: 'device_score',
    label: i18n.t('Device Score'),
    sortable: true,
    visible: true
  },
  device_type: {
    key: 'device_type',
    label: i18n.t('Device Type'),
    sortable: true,
    visible: true
  },
  device_version: {
    key: 'device_version',
    label: i18n.t('Device Version'),
    sortable: true,
    visible: true
  },
  dhcp6_enterprise: {
    key: 'dhcp6_enterprise',
    label: i18n.t('Device Enterprise'),
    sortable: true,
    visible: true
  },
  dhcp6_fingerprint: {
    key: 'dhcp6_fingerprint',
    label: i18n.t('DHCPv6 Fingerprint'),
    sortable: true,
    visible: true
  },
  dhcp_fingerprint: {
    key: 'dhcp_fingerprint',
    label: i18n.t('DHCP Fingerprint'),
    sortable: true,
    visible: true
  },
  dhcp_vendor: {
    key: 'dhcp_vendor',
    label: i18n.t('DHCP Vendor'),
    sortable: true,
    visible: true
  },
  end_time: {
    key: 'end_time',
    label: i18n.t('End Time'),
    sortable: true,
    visible: true
  },
  ip: {
    key: 'ip',
    label: i18n.t('IP Address'),
    sortable: true,
    visible: true
  },
  last_arp: {
    key: 'last_arp',
    label: i18n.t('Last ARP'),
    sortable: true,
    visible: true
  },
  last_dhcp: {
    key: 'last_dhcp',
    label: i18n.t('Last DHCP'),
    sortable: true,
    visible: true
  },
  last_seen: {
    key: 'last_seen',
    label: i18n.t('Last Seen'),
    sortable: true,
    visible: true
  },
  lastskip: {
    key: 'lastskip',
    label: i18n.t('Last Skip'),
    sortable: true,
    visible: true
  },
  mac: {
    key: 'mac',
    label: i18n.t('MAC Address'),
    sortable: true,
    visible: true
  },
  machine_account: {
    key: 'machine_account',
    label: i18n.t('Machine Account'),
    sortable: true,
    visible: true
  },
  nodes: {
    key: 'nodes',
    label: i18n.t('Nodes'),
    sortable: true,
    visible: true
  },
  notes: {
    key: 'notes',
    label: i18n.t('Notes'),
    sortable: true,
    visible: true
  },
  os: {
    key: 'os',
    label: i18n.t('Operating System'),
    sortable: true,
    visible: true
  },
  owner: {
    key: 'owner',
    label: i18n.t('Owner'),
    sortable: true,
    visible: true
  },
  percent: {
    key: 'percent',
    label: i18n.t('Percent'),
    sortable: true,
    visible: true
  },
  pid: {
    key: 'pid',
    label: i18n.t('PID'),
    sortable: true,
    visible: true
  },
  regdate: {
    key: 'reg_date',
    label: i18n.t('Registration Date'),
    sortable: true,
    visible: true
  },
  sessionid: {
    key: 'sessionid',
    label: i18n.t('Session ID'),
    sortable: true,
    visible: true
  },
  ssid: {
    key: 'ssid',
    label: i18n.t('SSID'),
    sortable: true,
    visible: true
  },
  start_date: {
    key: 'start_date',
    label: i18n.t('Start Date'),
    sortable: true,
    visible: true
  },
  start_time: {
    key: 'start_time',
    label: i18n.t('Start Time'),
    sortable: true,
    visible: true
  },
  status: {
    key: 'status',
    label: i18n.t('Status'),
    sortable: true,
    visible: true
  },
  time_balance: {
    key: 'time_balance',
    label: i18n.t('Time Balance'),
    sortable: true,
    visible: true
  },
  total: {
    key: 'total',
    label: i18n.t('Total'),
    sortable: true,
    visible: true
  },
  unregdate: {
    key: 'unregdate',
    label: i18n.t('Unregistration Date'),
    sortable: true,
    visible: true
  },
  user_agent: {
    key: 'user_agent',
    label: i18n.t('User Agent'),
    sortable: true,
    visible: true
  },
  user_name: {
    key: 'user_name',
    label: i18n.t('Username'),
    sortable: true,
    visible: true
  },
  vendor: {
    key: 'vendor',
    label: i18n.t('Vendor'),
    sortable: true,
    visible: true
  },
  violation: {
    key: 'violation',
    label: i18n.t('Violation'),
    sortable: true,
    visible: true
  },
  voip: {
    key: 'voip',
    label: i18n.t('VOIP'),
    sortable: true,
    visible: true
  }
}

export const pfReportCategories = [
  {
    name: i18n.t('Node'),
    reports: [
      {
        name: i18n.t('Operating System (All)'),
        path: 'os',
        columns: [
          pfReportColumns.description,
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: true
        }
      },
      {
        name: i18n.t('Operating System (Active)'),
        path: 'os/active',
        columns: [
          pfReportColumns.description,
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Operating System Class (All)'),
        path: 'osclass',
        columns: [
          pfReportColumns.description,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Operating System Class (Active)'),
        path: 'osclass/active',
        columns: [
          pfReportColumns.description,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Inactive'),
        path: 'inactive',
        columns: [
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.mac,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Active'),
        path: 'active',
        columns: [
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.ip,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.mac,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.start_time,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Unregistered'),
        path: 'unregistered',
        columns: [
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.mac,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Unregistered (Active)'),
        path: 'unregistered/active',
        columns: [
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.mac,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Registered'),
        path: 'registered',
        columns: [
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.mac,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Registered (Active)'),
        path: 'registered/active',
        columns: [
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.mac,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      }
    ]
  },
  {
    name: i18n.t('Fingerbank'),
    reports: [
      {
        name: i18n.t('Unknown Fingerprints'),
        path: 'unknownprints',
        columns: [
          pfReportColumns.computername,
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.mac,
          pfReportColumns.user_agent,
          pfReportColumns.vendor
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Unknown Fingerprints (Active)'),
        path: 'unknownprints/active',
        columns: [
          pfReportColumns.computername,
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.mac,
          pfReportColumns.user_agent,
          pfReportColumns.vendor
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Statics'),
        path: 'statics',
        columns: [
          pfReportColumns.autoreg,
          pfReportColumns.bandwidth_balance,
          pfReportColumns.bypass_role_id,
          pfReportColumns.bypass_vlan,
          pfReportColumns.category_id,
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.device_class,
          pfReportColumns.device_manufacturer,
          pfReportColumns.device_score,
          pfReportColumns.device_type,
          pfReportColumns.device_version,
          pfReportColumns.dhcp6_enterprise,
          pfReportColumns.dhcp6_fingerprint,
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.dhcp_vendor,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.last_seen,
          pfReportColumns.lastskip,
          pfReportColumns.mac,
          pfReportColumns.machine_account,
          pfReportColumns.notes,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.sessionid,
          pfReportColumns.status,
          pfReportColumns.time_balance,
          pfReportColumns.unregdate,
          pfReportColumns.user_agent,
          pfReportColumns.voip
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Statics (Active)'),
        path: 'statics/active',
        columns: [
          pfReportColumns.autoreg,
          pfReportColumns.bandwidth_balance,
          pfReportColumns.bypass_role_id,
          pfReportColumns.bypass_vlan,
          pfReportColumns.category_id,
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.device_class,
          pfReportColumns.device_manufacturer,
          pfReportColumns.device_score,
          pfReportColumns.device_type,
          pfReportColumns.device_version,
          pfReportColumns.dhcp6_enterprise,
          pfReportColumns.dhcp6_fingerprint,
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.dhcp_vendor,
          pfReportColumns.end_time,
          pfReportColumns.ip,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.last_seen,
          pfReportColumns.lastskip,
          pfReportColumns.mac,
          pfReportColumns.machine_account,
          pfReportColumns.notes,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.sessionid,
          pfReportColumns.start_time,
          pfReportColumns.status,
          pfReportColumns.time_balance,
          pfReportColumns.unregdate,
          pfReportColumns.user_agent,
          pfReportColumns.voip
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      }
    ]
  },
  {
    name: i18n.t('Violations'),
    reports: [
      {
        name: i18n.t('Open'),
        path: 'openviolations',
        columns: [
          pfReportColumns.mac,
          pfReportColumns.owner,
          pfReportColumns.start_date,
          pfReportColumns.status,
          pfReportColumns.violation
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Open (Active)'),
        path: 'openviolations/active',
        columns: [
          pfReportColumns.mac,
          pfReportColumns.owner,
          pfReportColumns.start_date,
          pfReportColumns.status,
          pfReportColumns.violation
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      }
    ]
  },
  {
    name: i18n.t('Connections'),
    reports: [
      {
        name: i18n.t('Type (All)'),
        path: 'connectiontype',
        columns: [
          pfReportColumns.connection_type,
          pfReportColumns.connections,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: true
        }
      },
      {
        name: i18n.t('Type (Active)'),
        path: 'connectiontype/active',
        columns: [
          pfReportColumns.connection_type,
          pfReportColumns.connections,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Type Registered (All)'),
        path: 'connectiontypereg',
        columns: [
          pfReportColumns.connection_type,
          pfReportColumns.connections,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Type Registered (Active)'),
        path: 'connectiontypereg/active',
        columns: [
          pfReportColumns.connection_type,
          pfReportColumns.connections,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('SSID (All)'),
        path: 'ssid',
        columns: [
          pfReportColumns.nodes,
          pfReportColumns.ssid,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: true
        }
      },
      {
        name: i18n.t('SSID (Active)'),
        path: 'ssid/active',
        columns: [
          pfReportColumns.nodes,
          pfReportColumns.ssid,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      }
    ]
  },
  {
    name: i18n.t('Accounting'),
    reports: [
      {
        name: i18n.t('Operating System Bandwidth (All)'),
        path: 'osclassbandwidth',
        columns: [
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.accttotal,
          pfReportColumns.accttotaloctets,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: true
        }
      },
      {
        name: i18n.t('Operating System Bandwidth (Day)'),
        path: 'osclassbandwidth/day',
        columns: [
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.accttotal,
          pfReportColumns.accttotaloctets,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Operating System Bandwidth (Week)'),
        path: 'osclassbandwidth/week',
        columns: [
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.accttotal,
          pfReportColumns.accttotaloctets,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Operating System Bandwidth (Month)'),
        path: 'osclassbandwidth/month',
        columns: [
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.accttotal,
          pfReportColumns.accttotaloctets,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Operating System Bandwidth (Year)'),
        path: 'osclassbandwidth/year',
        columns: [
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.accttotal,
          pfReportColumns.accttotaloctets,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: false
        }
      },
      {
        name: i18n.t('Node Bandwidth (All)'),
        path: 'nodebandwidth',
        columns: [
          pfReportColumns.callingstationid,
          pfReportColumns.acctinput,
          pfReportColumns.acctinputoctets,
          pfReportColumns.acctoutput,
          pfReportColumns.acctoutputoctets,
          pfReportColumns.accttotal,
          pfReportColumns.accttotaloctets,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: false,
          optional: true
        }
      }
    ]
  },
  {
    name: i18n.t('Authentication'),
    reports: [
      {
        name: i18n.t('Failures by MAC'),
        path: 'topauthenticationfailures/mac',
        columns: [
          pfReportColumns.mac,
          pfReportColumns.total,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: true,
          optional: false
        }
      },
      {
        name: i18n.t('Failures by SSID'),
        path: 'topauthenticationfailures/ssid',
        columns: [
          pfReportColumns.ssid,
          pfReportColumns.total,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: true,
          optional: false
        }
      },
      {
        name: i18n.t('Failures by Username'),
        path: 'topauthenticationfailures/username',
        columns: [
          pfReportColumns.user_name,
          pfReportColumns.total,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: true,
          optional: false
        }
      },
      {
        name: i18n.t('Successes by MAC'),
        path: 'topauthenticationsuccesses/mac',
        columns: [
          pfReportColumns.mac,
          pfReportColumns.total,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: true,
          optional: false
        }
      },
      {
        name: i18n.t('Successes by SSID'),
        path: 'topauthenticationsuccesses/ssid',
        columns: [
          pfReportColumns.ssid,
          pfReportColumns.total,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: true,
          optional: false
        }
      },
      {
        name: i18n.t('Successes by Username'),
        path: 'topauthenticationsuccesses/username',
        columns: [
          pfReportColumns.user_name,
          pfReportColumns.total,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: true,
          optional: false
        }
      },
      {
        name: i18n.t('Successes by Computername'),
        path: 'topauthenticationsuccesses/computername',
        columns: [
          pfReportColumns.computer_name,
          pfReportColumns.total,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        fields: [
          pfReportFields.mac
        ],
        range: {
          required: true,
          optional: false
        }
      }
    ]
  }
]
