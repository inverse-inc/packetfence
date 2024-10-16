import store from '@/store'
import { modes, libraries } from '../_components/Chart'

const chartFactory = (match, factory) => {
  return store.getters[`$_status/uniqueCharts`].reduce((defs, chart) => {
    const matches = match(chart)
    if (matches) {
      const append = factory(chart, matches)
      defs = [ ...defs, ...Array.isArray(append) ? append : [append] ]
    }
    return defs
  }, [])
}

export default [
  {
    name: 'Virtualization', // i18n defer
    groups: chartFactory(
      ({ id }) => id.match(/^cgroup_([a-z0-9-]{3,}).mem$/),
      //eslint-disable-next-line
      (chart, [metric, name]) => {
        return [
          {
            name,
            items: [
              {
                title: 'CPU', // i18n defer
                metric: `cgroup_${name}.cpu_limit`,
                mode: modes.COMBINED,
                library: libraries.DYGRAPH,
                cols: 6,
                params: {
                  dygraph_valuerange: "[0, 1]"
                }
              },
              {
                title: 'Memory', // i18n defer
                metric: `cgroup_${name}.mem`,
                mode: modes.COMBINED,
                library: libraries.DYGRAPH,
                cols: 6
              },
              {
                title: 'Disk I/O', // i18n defer
                metric: `cgroup_${name}.io`,
                mode: modes.COMBINED,
                library: libraries.DYGRAPH,
                cols: 6
              },
              ...chartFactory(
                ({ id }) => id.match(new RegExp(`^cgroup_${name}.net_([a-z]{1,}[0-9]{1,})$`)),
                //eslint-disable-next-line
                (chart, [_, iface]) => {
                  return [
                    {
                      title: `Network Bandwidth ${iface}`, // i18n defer
                      metric: `cgroup_${name}.net_${iface}`,
                      mode: modes.COMBINED,
                      library: libraries.DYGRAPH,
                      cols: 6
                    }
                  ].sort((a, b) => a.title.localeCompare(b.title))
                }
              )
            ]
          },
        ]
      }
    ).sort((a, b) => a.name.localeCompare(b.name)),

  }
]
