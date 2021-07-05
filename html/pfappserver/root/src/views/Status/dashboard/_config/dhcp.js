import { modes, libraries } from '../_components/Chart'

export default [
  {
    name: 'DHCP',
    groups: [
      {
        name: 'DHCP used leases', // i18n defer
        items: [
          {
            title: 'Numbers of ip addresses assigned', // i18n defer
            metric: 'packetfence.dhcp.used_leases',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      },
      {
        name: 'DHCP percent used leases', // i18n defer
        items: [
          {
            title: 'Percent of ip addresses used', // i18n defer
            metric: 'packetfence.dhcp.percent_used_leases',
            mode: modes.COMBINED,
            library: libraries.DYGRAPH,
            cols: 12
          }
        ]
      }
    ]
  }
]