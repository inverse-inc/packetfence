
/*
docker_local.containers_state
docker_local.healthy_containers
docker_local.container_netdata_health_status
docker_local.images_count
docker_local.images_size
docker_local.container_httpd.portal_state
docker_local.container_httpd.portal_health_status
docker_local.container_haproxy-admin_state
docker_local.container_haproxy-admin_health_status
docker_local.container_haproxy-portal_state
docker_local.container_haproxy-portal_health_status
docker_local.container_httpd.dispatcher_state
docker_local.container_httpd.dispatcher_health_status
docker_local.container_ntlm-auth-api-test_state
docker_local.container_ntlm-auth-api-test_health_status
docker_local.container_pfpki_state
docker_local.container_pfpki_health_status
docker_local.container_httpd.aaa_state
docker_local.container_httpd.aaa_health_status
docker_local.container_httpd.webservices_state
docker_local.container_httpd.webservices_health_status
docker_local.container_pfconnector-server_state
docker_local.container_pfconnector-server_health_status
docker_local.container_pfacct_state
docker_local.container_pfacct_health_status
docker_local.container_api-frontend_state
docker_local.container_api-frontend_health_status
docker_local.container_pfsso_state
docker_local.container_pfsso_health_status
docker_local.container_pfldapexplorer_state
docker_local.container_pfldapexplorer_health_status
docker_local.container_pfcron_state
docker_local.container_pfcron_health_status
docker_local.container_pfconnector-client_state
docker_local.container_pfconnector-client_health_status
docker_local.container_httpd.admin_dispatcher_state
docker_local.container_httpd.admin_dispatcher_health_status
docker_local.container_pfperl-api_state
docker_local.container_pfperl-api_health_status
docker_local.container_pfconfig_state
docker_local.container_pfconfig_health_status
docker_local.container_netdata_state
docker_local.container_netdata_health_status
*/
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
                  //eslint-disable-next-line
                  console.log({ name, iface })
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
