import { modes, libraries, palettes } from '../_components/Chart'

export default [
  {
    name: 'System', // i18n defer
    groups: [
      {
        items: [
          {
            title: 'Registered devices per role', // i18n defer
            metric: 'packetfence.devices.registered_per_role',
            mode: modes.LOCAL,
            library: libraries.D3PIE,
            params: {
              d3pie_smallsegmentgrouping_value: 0.5,
              d3pie_smallsegmentgrouping_enabled: 'true',
              decimal_digits: 0
            },
            cols: 4
          },
          {
            title: 'Connected devices per connection type', // i18n defer
            metric: 'packetfence.devices.connected_per_connection_type',
            mode: modes.LOCAL,
            library: libraries.D3PIE,
            params: {
              decimal_digits: 0,
              colors: palettes[1]
            },
            cols: 4
          },
          {
            title: 'Connected devices per SSID', // i18n defer
            metric: 'packetfence.devices.connected_per_ssid',
            mode: modes.LOCAL,
            library: libraries.D3PIE,
            params: {
              d3pie_smallsegmentgrouping_value: 0.5,
              d3pie_smallsegmentgrouping_enabled: 'true',
              decimal_digits: 0,
              colors: palettes[2]
            },
            cols: 4
          }
        ]
      },
      {
        items: [
          {
            title: 'Registered Devices', // i18n defer
            metric: 'statsd_source.packetfence.devices.registered_gauge',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH_COUNTER,
            params: {
              decimal_digits: 0,
              dygraph_theme: 'sparkline',
              dygraph_type: 'area',
              dimensions: 'gauge'
            },
            cols: 3
          },
          {
            title: 'Open security events', // i18n defer
            metric: 'statsd_source.packetfence.security_events_gauge',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH_COUNTER,
            params: {
              decimal_digits: 0,
              dygraph_theme: 'sparkline',
              dygraph_type: 'area',
              dimensions: 'gauge'
            },
            cols: 3
          }
        ]
      },
      {
        name: 'System', // i18n defer
        items: [
          {
            title: 'CPU usage', // i18n defer
            metric: 'system.cpu',
            mode: modes.SINGLE,
            library: libraries.DYGRAPH,
            params: {
              dimensions: 'user,system',
              dygraph_valuerange: '[0, 100]'
            },
            cols: 6
          },
          {
            title: 'IO Wait/Soft IRQ', // i18n defer
            metric: 'system.cpu',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              dimensions: 'iowait,softirq',
              dygraph_valuerange: '[0, 100]'
            },
            cols: 6
          },
          {
            title: 'System Load Average', // i18n defer
            metric: 'system.load',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Disk I/O', // i18n defer
            metric: 'system.io',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Disk Space Usage for /', // i18n defer
            metric: 'disk_space._',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'System RAM', // i18n defer
            metric: 'system.ram',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'System Swap Used', // i18n defer
            metric: 'mem.swap',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            params: {
              dimensions: 'used'
            },
            cols: 6
          },
          {
            title: 'Swap IO', // i18n defer
            metric: 'mem.swapio',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      },
      {
        name: 'Physical Network Interfaces', // i18n defer
        items: [
          {
            title: 'Aggregated Bandwidth', // i18n defer
            metric: 'system.net',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'IPv4 Networking', // i18n defer
        items: [
          {
            title: 'Bandwidth', // i18n defer
            metric: 'system.ip',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Packets', // i18n defer
            metric: 'ipv4.packets',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Errors', // i18n defer
            metric: 'ipv4.errors',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 4
          },
          {
            title: 'TCP Sockets', // i18n defer
            metric: 'ipv4.sockstat_tcp_sockets',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 4
          },
          {
            title: 'UDP Sockets', // i18n defer
            metric: 'ipv4.sockstat_udp_sockets',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 4
          }
        ]
      },
      {
        name: 'IPv6 Networking', // i18n defer
        items: [
          {
            title: 'Bandwidth', // i18n defer
            metric: 'system.ipv6',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Packets', // i18n defer
            metric: 'ipv6.packets',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Errors', // i18n defer
            metric: 'ipv6.errors',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 4
          },
          {
            title: 'TCP Sockets', // i18n defer
            metric: 'ipv6.sockstat6_tcp_sockets',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 4
          },
          {
            title: 'UDP Sockets', // i18n defer
            metric: 'ipv6.sockstat6_udp_sockets',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 4
          }
        ]
      },
      {
        name: 'Database', // i18n defer
        items: [
          {
            title: 'Database queries', // i18n defer
            metric: 'mysql_PacketFence_Database.queries',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Database handlers', // i18n defer
            metric: 'mysql_PacketFence_Database.handlers',
            mode: modes.LOCAL,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Database threads', // i18n defer
            metric: 'mysql_PacketFence_Database.threads',
            mode: modes.SINGLE,
            library: libraries.DYGRAPH,
            cols: 6
          },
          {
            title: 'Database connections', // i18n defer
            metric: 'mysql_PacketFence_Database.connections',
            mode: modes.SINGLE,
            library: libraries.DYGRAPH,
            cols: 6
          }
        ]
      }
    ]
  }
]