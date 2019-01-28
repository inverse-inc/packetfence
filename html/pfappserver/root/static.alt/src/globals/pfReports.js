import i18n from '@/utils/locale'
import store from '@/store'
import { pfFormatters as formatter } from '@/globals/pfFormatters'

export const pfReportChartColorsFull = ['#ffff00', '#1ce6ff', '#ff34ff', '#ff4a46', '#008941', '#006fa6', '#a30059', '#ffdbe5', '#7a4900', '#0000a6', '#63ffac', '#b79762', '#004d43', '#8fb0ff', '#997d87', '#5a0007', '#809693', '#feffe6', '#1b4400', '#4fc601', '#3b5dff', '#4a3b53', '#ff2f80', '#61615a', '#ba0900', '#6b7900', '#00c2a0', '#ffaa92', '#ff90c9', '#b903aa', '#d16100', '#ddefff', '#000035', '#7b4f4b', '#a1c299', '#300018', '#0aa6d8', '#013349', '#00846f', '#372101', '#ffb500', '#c2ffed', '#a079bf', '#cc0744', '#c0b9b2', '#c2ff99', '#001e09', '#00489c', '#6f0062', '#0cbd66', '#eec3ff', '#456d75', '#b77b68', '#7a87a1', '#788d66', '#885578', '#fad09f', '#ff8a9a', '#d157a0', '#bec459', '#456648', '#0086ed', '#886f4c', '#34362d', '#b4a8bd', '#00a6aa', '#452c2c', '#636375', '#a3c8c9', '#ff913f', '#938a81', '#575329', '#00fecf', '#b05b6f', '#8cd0ff', '#3b9700', '#04f757', '#c8a1a1', '#1e6e00', '#7900d7', '#a77500', '#6367a9', '#a05837', '#6b002c', '#772600', '#d790ff', '#9b9700', '#549e79', '#fff69f', '#201625', '#72418f', '#bc23ff', '#99adc0', '#3a2465', '#922329', '#5b4534', '#fde8dc', '#404e55', '#0089a3', '#cb7e98', '#a4e804', '#324e72', '#6a3a4c', '#83ab58', '#001c1e', '#d1f7ce', '#004b28', '#c8d0f6', '#a3a489', '#806c66', '#222800', '#bf5650', '#e83000', '#66796d', '#da007c', '#ff1a59', '#8adbb4', '#1e0200', '#5b4e51', '#c895c5', '#320033', '#ff6832', '#66e1d3', '#cfcdac', '#d0ac94', '#7ed379', '#012c58', '#7a7bff', '#d68e01', '#353339', '#78afa1', '#feb2c6', '#75797c', '#837393', '#943a4d', '#b5f4ff', '#d2dcd5', '#9556bd', '#6a714a', '#001325', '#02525f', '#0aa3f7', '#e98176', '#dbd5dd', '#5ebcd1', '#3d4f44', '#7e6405', '#02684e', '#962b75', '#8d8546', '#9695c5', '#e773ce', '#d86a78', '#3e89be', '#ca834e', '#518a87', '#5b113c', '#55813b', '#e704c4', '#00005f', '#a97399', '#4b8160', '#59738a', '#ff5da7', '#f7c9bf', '#643127', '#513a01', '#6b94aa', '#51a058', '#a45b02', '#1d1702', '#e20027', '#e7ab63', '#4c6001', '#9c6966', '#64547b', '#97979e', '#006a66', '#391406', '#f4d749', '#0045d2', '#006c31', '#ddb6d0', '#7c6571', '#9fb2a4', '#00d891', '#15a08a', '#bc65e9', '#fffffe', '#c6dc99', '#203b3c', '#671190', '#6b3a64', '#f5e1ff', '#ffa0f2', '#ccaa35', '#374527', '#8bb400', '#797868', '#c6005a', '#3b000a', '#c86240', '#29607c', '#402334', '#7d5a44', '#ccb87c', '#b88183', '#aa5199', '#b5d6c3', '#a38469', '#9f94f0', '#a74571', '#b894a6', '#71bb8c', '#00b433', '#789ec9', '#6d80ba', '#953f00', '#5eff03', '#e4fffc', '#1be177', '#bcb1e5', '#76912f', '#003109', '#0060cd', '#d20096', '#895563', '#29201d', '#5b3213', '#a76f42', '#89412e', '#1a3a2a', '#494b5a', '#a88c85', '#f4abaa', '#a3f3ab', '#00c6c8', '#ea8b66', '#958a9f', '#bdc9d2', '#9fa064', '#be4700', '#658188', '#83a485', '#453c23', '#47675d', '#3a3f00', '#061203', '#dffb71', '#868e7e', '#98d058', '#6c8f7d', '#d7bfc2', '#3c3e6e', '#d83d66', '#000000']

export const pfReportChartColorsNull = ['#eeeeee']

export const pfReportChartLayout = {
  pie: {
    autosize: true,
    hoverdistance: 100,
    hovermode: 'closest',
    spikedistance: 100,
    legend: {
      bgcolor: '#eee',
      bordercolor: '#eee',
      borderwidth: 10,
      orientation: 'v',
      xanchor: 'center',
      x: 1,
      y: 0.5
    },
    margin: {
      l: 25,
      r: 25,
      b: 50,
      t: 50,
      pad: 20,
      autoexpand: true
    }
  }
}

export const pfReportChartOptions = {
  pie: {
    type: 'pie',
    domain: {
      x: [0, 1],
      y: [0, 1]
    },
    hoverinfo: 'label+percent',
    hole: 0.25,
    marker: {
      line: {
        width: 0.5
      }
    },
    outsidetextfont: {
      family: '"Open Sans", verdana, arial, sans-serif',
      size: 12,
      color: '#444'
    },
    pull: 0,
    sort: true,
    textinfo: 'label',
    textfont: {
      family: '"Open Sans", verdana, arial, sans-serif',
      size: 12,
      color: '#444'
    },
    textposition: 'outside'
  }
}

export const pfReportSort = {
  role: (a, b) => {
    switch (true) {
      case a === b: return 0
      case !a: return -1
      case !b: return 1
      default:
        const aName = store.state.config.roles.filter(role => role.category_id === a).map(role => role.name)[0]
        const bName = store.state.config.roles.filter(role => role.category_id === b).map(role => role.name)[0]
        return toString(aName).localeCompare(toString(bName), undefined, { numeric: true })
    }
  }
}

export const pfReportColumns = {
  acctinput: {
    key: 'acctinput',
    label: i18n.t('Bytes In'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  acctinputoctets: {
    key: 'acctinputoctets',
    label: i18n.t('Octets In'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  acctoutput: {
    key: 'acctoutput',
    label: i18n.t('Bytes Out'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  acctoutputoctets: {
    key: 'acctoutputoctets',
    label: i18n.t('Octets Out'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  accttotal: {
    key: 'accttotal',
    label: i18n.t('Bytes Total'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  accttotaloctets: {
    key: 'accttotaloctets',
    label: i18n.t('Octets Total'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  autoreg: {
    key: 'autoreg',
    label: i18n.t('Auto Registration'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  bandwidth_balance: {
    key: 'bandwidth_balance',
    label: i18n.t('Bandwidth Balance'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  bypass_role_id: {
    key: 'bypass_role_id',
    label: i18n.t('Bypass Role'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.bypassRoleId,
    sort: pfReportSort.role
  },
  bypass_vlan: {
    key: 'bypass_vlan',
    label: i18n.t('Bypass VLAN'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  callingstationid: {
    key: 'callingstationid',
    label: i18n.t('Calling Station ID'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  category_id: {
    key: 'category_id',
    label: i18n.t('Role'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.categoryId,
    sort: pfReportSort.role
  },
  computer_name: {
    key: 'computer_name',
    label: i18n.t('Computername'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  connection_type: {
    key: 'connection_type',
    label: i18n.t('Connection Type'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  connections: {
    key: 'connections',
    label: i18n.t('Connections'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  computername: {
    key: 'computername',
    label: i18n.t('Computername'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  count: {
    key: 'count',
    label: i18n.t('Count'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  description: {
    key: 'description',
    label: i18n.t('Description'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  detect_date: {
    key: 'detect_date',
    label: i18n.t('Detect Date'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero
  },
  device_class: {
    key: 'device_class',
    label: i18n.t('Device Class'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  device_manufacturer: {
    key: 'device_manufacturer',
    label: i18n.t('Device Manufacturer'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  device_score: {
    key: 'device_score',
    label: i18n.t('Device Score'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  device_type: {
    key: 'device_type',
    label: i18n.t('Device Type'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  device_version: {
    key: 'device_version',
    label: i18n.t('Device Version'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  dhcp6_enterprise: {
    key: 'dhcp6_enterprise',
    label: i18n.t('Device Enterprise'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  dhcp6_fingerprint: {
    key: 'dhcp6_fingerprint',
    label: i18n.t('DHCPv6 Fingerprint'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  dhcp_fingerprint: {
    key: 'dhcp_fingerprint',
    label: i18n.t('DHCP Fingerprint'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  dhcp_vendor: {
    key: 'dhcp_vendor',
    label: i18n.t('DHCP Vendor'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  end_time: {
    key: 'end_time',
    label: i18n.t('End Time'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  ip: {
    key: 'ip',
    label: i18n.t('IP Address'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  last_arp: {
    key: 'last_arp',
    label: i18n.t('Last ARP'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero
  },
  last_dhcp: {
    key: 'last_dhcp',
    label: i18n.t('Last DHCP'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero
  },
  last_seen: {
    key: 'last_seen',
    label: i18n.t('Last Seen'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero
  },
  lastskip: {
    key: 'lastskip',
    label: i18n.t('Last Skip'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero
  },
  mac: {
    key: 'mac',
    label: i18n.t('MAC Address'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  machine_account: {
    key: 'machine_account',
    label: i18n.t('Machine Account'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  nodes: {
    key: 'nodes',
    label: i18n.t('Nodes'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  notes: {
    key: 'notes',
    label: i18n.t('Notes'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  os: {
    key: 'os',
    label: i18n.t('Operating System'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  owner: {
    key: 'owner',
    label: i18n.t('Owner'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  percent: {
    key: 'percent',
    label: i18n.t('Percent'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  pid: {
    key: 'pid',
    label: i18n.t('PID'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  regdate: {
    key: 'reg_date',
    label: i18n.t('Registration Date'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero
  },
  sessionid: {
    key: 'sessionid',
    label: i18n.t('Session ID'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  ssid: {
    key: 'ssid',
    label: i18n.t('SSID'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  start_date: {
    key: 'start_date',
    label: i18n.t('Start Date'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero
  },
  start_time: {
    key: 'start_time',
    label: i18n.t('Start Time'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  status: {
    key: 'status',
    label: i18n.t('Status'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  time_balance: {
    key: 'time_balance',
    label: i18n.t('Time Balance'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  total: {
    key: 'total',
    label: i18n.t('Total'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  unregdate: {
    key: 'unregdate',
    label: i18n.t('Unregistration Date'),
    class: 'text-nowrap',
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero
  },
  user_agent: {
    key: 'user_agent',
    label: i18n.t('User Agent'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  user_name: {
    key: 'user_name',
    label: i18n.t('Username'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  vendor: {
    key: 'vendor',
    label: i18n.t('Vendor'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  security_event: {
    key: 'security_event',
    label: i18n.t('SecurityEvent'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  },
  voip: {
    key: 'voip',
    label: i18n.t('VOIP'),
    class: 'text-nowrap',
    sortable: true,
    visible: true
  }
}

export const pfReportCategories = [
  {
    name: i18n.t('Node'),
    reports: [
      {
        name: i18n.t('Operating System'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'os',
            range: {
              optional: true
            }
          },
          {
            name: i18n.t('Active'),
            path: 'os/active'
          }
        ],
        columns: [
          pfReportColumns.description,
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        chart: {
          labels: (items) => {
            items.pop() // pop Total
            return items.map(item => item.description)
          },
          values: (items) => {
            items.pop() // pop Total
            return items.map(item => item.count)
          },
          options: pfReportChartOptions.pie,
          layout: pfReportChartLayout.pie
        }
      },
      {
        name: i18n.t('Operating System Class'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'osclass'
          },
          {
            name: i18n.t('Active'),
            path: 'osclass/active'
          }
        ],
        columns: [
          pfReportColumns.description,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        chart: {
          labels: (items) => {
            items.pop() // pop Total
            return items.map(item => item.description)
          },
          values: (items) => {
            items.pop() // pop Total
            return items.map(item => item.count)
          },
          options: pfReportChartOptions.pie,
          layout: pfReportChartLayout.pie
        }
      },
      {
        name: i18n.t('Inactive'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'inactive'
          }
        ],
        columns: [
          pfReportColumns.mac,
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ]
      },
      {
        name: i18n.t('Active'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'active'
          }
        ],
        columns: [
          pfReportColumns.mac,
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.ip,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.start_time,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ]
      },
      {
        name: i18n.t('Unregistered'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'unregistered'
          },
          {
            name: i18n.t('Active'),
            path: 'unregistered/active'
          }
        ],
        columns: [
          pfReportColumns.mac,
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ]
      },
      {
        name: i18n.t('Registered'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'registered'
          },
          {
            name: i18n.t('Active'),
            path: 'registered/active'
          }
        ],
        columns: [
          pfReportColumns.mac,
          pfReportColumns.computername,
          pfReportColumns.detect_date,
          pfReportColumns.last_arp,
          pfReportColumns.last_dhcp,
          pfReportColumns.lastskip,
          pfReportColumns.notes,
          pfReportColumns.os,
          pfReportColumns.pid,
          pfReportColumns.regdate,
          pfReportColumns.status,
          pfReportColumns.user_agent
        ]
      }
    ]
  },
  {
    name: i18n.t('Fingerbank'),
    reports: [
      {
        name: i18n.t('Unknown Fingerprints'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'unknownprints'
          },
          {
            name: i18n.t('Active'),
            path: 'unknownprints/active'
          }
        ],
        columns: [
          pfReportColumns.mac,
          pfReportColumns.computername,
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.user_agent,
          pfReportColumns.vendor
        ]
      },
      {
        name: i18n.t('Statics'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'statics'
          },
          {
            name: i18n.t('Active'),
            path: 'statics/active'
          }
        ],
        columns: [
          pfReportColumns.mac,
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
        ]
      }
    ]
  },
  {
    name: i18n.t('SecurityEvents'),
    reports: [
      {
        name: i18n.t('Open'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'opensecurity_events'
          },
          {
            name: i18n.t('Active'),
            path: 'opensecurity_events/active'
          }
        ],
        columns: [
          pfReportColumns.mac,
          pfReportColumns.owner,
          pfReportColumns.start_date,
          pfReportColumns.status,
          pfReportColumns.security_event
        ]
      }
    ]
  },
  {
    name: i18n.t('Connections'),
    reports: [
      {
        name: i18n.t('Type'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'connectiontype',
            range: {
              optional: true
            }
          },
          {
            name: i18n.t('Active'),
            path: 'connectiontype/active'
          }
        ],
        columns: [
          pfReportColumns.connection_type,
          pfReportColumns.connections,
          pfReportColumns.percent
        ],
        chart: {
          labels: (items) => {
            items.pop() // pop Total
            return items.map(item => item.connection_type)
          },
          values: (items) => {
            items.pop() // pop Total
            return items.map(item => item.connections)
          },
          options: pfReportChartOptions.pie,
          layout: pfReportChartLayout.pie
        }
      },
      {
        name: i18n.t('Type Registered'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'connectiontypereg'
          },
          {
            name: i18n.t('Active'),
            path: 'connectiontypereg/active'
          }
        ],
        columns: [
          pfReportColumns.connection_type,
          pfReportColumns.connections,
          pfReportColumns.percent
        ],
        chart: {
          labels: (items) => {
            items.pop() // pop Total
            return items.map(item => item.connection_type)
          },
          values: (items) => {
            items.pop() // pop Total
            return items.map(item => item.connections)
          },
          options: pfReportChartOptions.pie,
          layout: pfReportChartLayout.pie
        }
      },
      {
        name: i18n.t('SSID (All)'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'ssid',
            range: {
              optional: true
            }
          },
          {
            name: i18n.t('Active'),
            path: 'ssid/active'
          }
        ],
        columns: [
          pfReportColumns.ssid,
          pfReportColumns.nodes,
          pfReportColumns.percent
        ],
        chart: {
          labels: (items) => {
            items.pop() // pop Total
            return items.map(item => item.ssid)
          },
          values: (items) => {
            items.pop() // pop Total
            return items.map(item => item.nodes)
          },
          options: pfReportChartOptions.pie,
          layout: pfReportChartLayout.pie
        }
      }
    ]
  },
  {
    name: i18n.t('Accounting'),
    reports: [
      {
        name: i18n.t('Operating System Bandwidth'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'osclassbandwidth',
            range: {
              optional: true
            }
          },
          {
            name: i18n.t('Day'),
            path: 'osclassbandwidth/day'
          },
          {
            name: i18n.t('Week'),
            path: 'osclassbandwidth/week'
          },
          {
            name: i18n.t('Month'),
            path: 'osclassbandwidth/month'
          },
          {
            name: i18n.t('Year'),
            path: 'osclassbandwidth/year'
          }
        ],
        columns: [
          pfReportColumns.dhcp_fingerprint,
          pfReportColumns.accttotal,
          pfReportColumns.accttotaloctets,
          pfReportColumns.percent
        ],
        chart: {
          labels: (items) => {
            items.pop() // pop Total
            return items.map(item => item.dhcp_fingerprint)
          },
          values: (items) => {
            items.pop() // pop Total
            return items.map(item => item.accttotaloctets)
          },
          options: pfReportChartOptions.pie,
          layout: pfReportChartLayout.pie
        }
      },
      {
        name: i18n.t('Node Bandwidth'),
        tabs: [
          {
            name: i18n.t('All'),
            path: 'nodebandwidth',
            range: {
              optional: true
            }
          }
        ],
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
        chart: {
          labels: (items) => {
            items.pop() // pop Total
            return items.map(item => item.callingstationid)
          },
          values: (items) => {
            items.pop() // pop Total
            return items.map(item => item.accttotaloctets)
          },
          options: pfReportChartOptions.pie,
          layout: pfReportChartLayout.pie
        }
      }
    ]
  },
  {
    name: i18n.t('Authentication'),
    reports: [
      {
        name: i18n.t('Failures'),
        tabs: [
          {
            name: 'by MAC',
            path: 'topauthenticationfailures/mac',
            range: {
              required: true
            }
          },
          {
            name: 'by SSID',
            path: 'topauthenticationfailures/ssid',
            range: {
              required: true
            }
          },
          {
            name: 'by Username',
            path: 'topauthenticationfailures/username',
            range: {
              required: true
            }
          }
        ],
        columns: [
          pfReportColumns.mac,
          pfReportColumns.total,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        chart: {
          labels: (items) => {
            items.pop() // pop Total
            return items.map(item => item.mac)
          },
          values: (items) => {
            items.pop() // pop Total
            return items.map(item => item.count)
          },
          options: pfReportChartOptions.pie,
          layout: pfReportChartLayout.pie
        }
      },
      {
        name: i18n.t('Successes'),
        tabs: [
          {
            name: 'by MAC',
            path: 'topauthenticationsuccesses/mac',
            range: {
              required: true
            }
          },
          {
            name: 'by SSID',
            path: 'topauthenticationsuccesses/ssid',
            range: {
              required: true
            }
          },
          {
            name: 'by Username',
            path: 'topauthenticationsuccesses/username',
            range: {
              required: true
            }
          },
          {
            name: 'by Computername',
            path: 'topauthenticationsuccesses/computername',
            range: {
              required: true
            }
          }
        ],
        columns: [
          pfReportColumns.mac,
          pfReportColumns.total,
          pfReportColumns.count,
          pfReportColumns.percent
        ],
        chart: {
          labels: (items) => {
            items.pop() // pop Total
            return items.map(item => item.mac)
          },
          values: (items) => {
            items.pop() // pop Total
            return items.map(item => item.count)
          },
          options: pfReportChartOptions.pie,
          layout: pfReportChartLayout.pie
        }
      }
    ]
  }
]
