<template>
    <b-container class="my-3" fluid>
      <b-alert variant="danger" :show="chartsError" fade>
        <h4 class="alert-heading" v-t="'Error'"></h4>
        <p>{{ $t('The charts of the dasboard are currently not available.') }}</p>
        <pf-button-service service="netdata" class="mr-1" restart start></pf-button-service>
      </b-alert>
      <b-tabs nav-class="nav-fill">
        <b-tab v-for="section in sections" :title="section.name" :key="section.name">
          <template v-for="group in section.groups">
            <!-- Named groups are rendered inside a card -->
            <component :is="group.name ? 'b-card' : 'div'" class="mt-3" :key="group.name" :title="group.name">
              <b-row align-h="center">
                <template v-for="chart in group.items">
                <b-col class="mt-3" :md="cols(chart.cols, group.items.length)" v-for="(host, index) in chartHosts(chart)" :key="chart.metric + host">
                  <chart :store-name="storeName" :definition="chart" :host="host" :data-colors="palette(index)"></chart>
                </b-col>
                </template>
              </b-row>
            </component>
          </template>
        </b-tab>
      </b-tabs>

    <!-- Initial customizable dashboard -- disabled for now

    <b-row align-h="center">
      <b-col class="mt-3" :md="chart.cols" v-for="chart in charts" :key="chart.id">
        <div :data-netdata="chart.name"
              :data-title="chart.title"
              :data-chart-library="chart.library"
              role="application"></div>
      </b-col>
      <b-col cols="3">
        <b-alert show variant="secondary" class="mt-3">
          <b-form-select v-model="new_chart.id" class="mb-1">
              <option value="null" disabled>Select a chart</option>
              <optgroup v-for="module in all_modules" :label="module" :key="module">
                  <option v-for="chart in moduleCharts(module)" :key="chart.id" :value="chart.id">{{ chart.name }}</option>
              </optgroup>
          </b-form-select>
          <b-form-select v-model="new_chart.library" class="mb-1">
              <option :value="null" disabled>Select a library</option>
              <option v-for="lib in libs" :value="lib" :key="lib">{{ lib }}</option>
          </b-form-select>
          <b-form-select v-model="new_chart.cols" class="mb-3">
              <option :value="null" disabled>Select a number of columns</option>
              <option :value="col" v-for="col in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]" :key="col">{{ col }}</option>
          </b-form-select>
          <b-button @click="addChart(new_chart)" :disabled="!new_chart_valid">Add chart</b-button>
        </b-alert>
      </b-col>
    </b-row> -->
  </b-container>
</template>

<script>
import Chart, { modes, libs, palettes } from './Chart'
import pfButtonService from '@/components/pfButtonService'

export default {
  name: 'Dashboard',
  components: {
    Chart,
    pfButtonService
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      new_chart: {
        id: null,
        cols: 6,
        library: libs.DYGRAPH
      },
      allSections: [
        {
          name: this.$i18n.t('System'),
          groups: [
            {
              items: [
                {
                  title: this.$i18n.t('Registered devices per role'),
                  metric: 'packetfence.devices.registered_per_role',
                  mode: modes.LOCAL,
                  library: libs.D3PIE,
                  params: {
                    d3pie_smallsegmentgrouping_value: 0.5,
                    d3pie_smallsegmentgrouping_enabled: 'true',
                    decimal_digits: 0
                  },
                  cols: 3
                },
                {
                  title: this.$i18n.t('Connected devices per connection type'),
                  metric: 'packetfence.devices.connected_per_connection_type',
                  mode: modes.LOCAL,
                  library: libs.D3PIE,
                  params: {
                    decimal_digits: 0,
                    colors: palettes[1]
                  },
                  cols: 3
                },
                {
                  title: this.$i18n.t('Connected devices per SSID'),
                  metric: 'packetfence.devices.connected_per_ssid',
                  mode: modes.LOCAL,
                  library: libs.D3PIE,
                  params: {
                    d3pie_smallsegmentgrouping_value: 0.5,
                    d3pie_smallsegmentgrouping_enabled: 'true',
                    decimal_digits: 0,
                    colors: palettes[2]
                  },
                  cols: 3
                }
              ]
            },
            {
              items: [
                {
                  title: this.$i18n.t('Registered Devices'),
                  metric: 'statsd_gauge_source.packetfence.devices.registered',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH_COUNTER,
                  params: {
                    decimal_digits: 0,
                    dygraph_theme: 'sparkline',
                    dygraph_type: 'area',
                    dimensions: 'gauge'
                  },
                  cols: 3
                },
                {
                  title: this.$i18n.t('Open security events'),
                  metric: 'statsd_gauge_source.packetfence.security_events',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH_COUNTER,
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
              name: this.$i18n.t('System'),
              items: [
                {
                  title: this.$i18n.t('CPU usage'),
                  metric: 'system.cpu',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    dimensions: 'user,system',
                    dygraph_valuerange: '[0, 100]'
                  },
                  cols: 6
                },
                {
                  title: this.$i18n.t('IO Wait/Soft IRQ'),
                  metric: 'system.cpu',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    dimensions: 'iowait,softirq',
                    dygraph_valuerange: '[0, 100]'
                  },
                  cols: 6
                },
                {
                  title: this.$i18n.t('System Load Average'),
                  metric: 'system.load',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('Disk I/O'),
                  metric: 'system.io',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('Disk Space Usage for /'),
                  metric: 'disk_space._',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('System RAM'),
                  metric: 'system.ram',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('System Swap Used'),
                  metric: 'system.swap',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    dimensions: 'used'
                  },
                  cols: 6
                },
                {
                  title: this.$i18n.t('Swap IO'),
                  metric: 'system.swapio',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                }
              ]
            },
            {
              name: this.$i18n.t('IPv4 Networking'),
              items: [
                {
                  title: this.$i18n.t('IPv4 Bandwidth'),
                  metric: 'system.ipv4',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('IPv4 Sockets'),
                  metric: 'ipv4.sockstat_sockets',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                }
              ]
            },
            {
              name: this.$i18n.t('Database'),
              items: [
                {
                  title: this.$i18n.t('Database queries'),
                  metric: 'mysql_PacketFence_Database.queries',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('Database handlers'),
                  metric: 'mysql_PacketFence_Database.handlers',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('Database threads'),
                  metric: 'mysql_PacketFence_Database.threads',
                  mode: modes.SINGLE,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('Database connections'),
                  metric: 'mysql_PacketFence_Database.connections',
                  mode: modes.SINGLE,
                  library: libs.DYGRAPH,
                  cols: 6
                }
              ]
            }
          ] // groups
        }, // System section
        {
          name: this.$i18n.t('RADIUS'),
          groups: [
            {
              name: this.$i18n.t('RADIUS Latency'),
              items: [
                {
                  title: this.$i18n.t('Auth Rest'),
                  metric: 'statsd_timer_pf__api__radius_rest_authorize.timing',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: 'average'
                  },
                  cols: 6
                },
                {
                  title: this.$i18n.t('Acct Rest'),
                  metric: 'statsd_timer_pf__api__radius_rest_accounting.timing',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: 'average'
                  },
                  cols: 6
                }
              ]
            },
            {
              name: this.$i18n.t('RADIUS Requests'),
              items: [
                {
                  title: this.$i18n.t('Load balancer auth'),
                  metric: 'freeradius_Freeradius_LoadBalancer.proxy-auth',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('Load balancer acct'),
                  metric: 'freeradius_Freeradius_LoadBalancer.proxy-acct',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('RADIUS auth'),
                  metric: 'freeradius_Freeradius_Auth.authentication',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('RADIUS acct'),
                  metric: 'freeradius_Freeradius_Acct.accounting',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 6
                }
              ]
            },
            {
              name: 'NTLM',
              items: [
                {
                  title: this.$i18n.t('NTLM latency'),
                  metric: 'statsd_timer_ntlm_auth.time',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: 'average'
                  },
                  cols: 6
                },
                {
                  title: this.$i18n.t('NTLM failures'),
                  metric: 'statsd_counter_ntlm_auth.failures',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: 'counter'
                  },
                  cols: 6
                }
              ]
            }
          ] // groups
        }, // RADIUS section
        {
          name: this.$i18n.t('Authentication'),
          groups: [
            {
              name: this.$i18n.t('Authentication Sources'), // requires sources
              items: () => {
                const { $store: { state: { config: { sources = [] } = {} } = {} } = {} } = this
                return [].concat.apply([], sources.filter(source => source.monitor && source.host).map(source => {
                  return source.host.split(',').map(host => {
                    return {
                      title: `${source.description} - ping ${host}`,
                      metric: `fping.${host.replace(/\./g, '_')}_latency`,
                      mode: modes.LOCAL,
                      library: libs.DYGRAPH,
                      cols: 6
                    }
                  })
                }))
              }
            },
            {
              name: this.$i18n.t('Successful & Unsuccessful RADIUS Authentications'),
              items: [
                {
                  title: this.$i18n.t('Successful RADIUS authentications in the last day'),
                  metric: 'statsd_gauge_source.packetfence.authentication.success_last_day',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('Failed RADIUS authentications in the last day'),
                  metric: 'statsd_gauge_source.packetfence.authentication.failed_last_day',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  cols: 6
                }
              ]
            }
          ] // groups
        }, // Authentication section
        {
          name: 'DHCP',
          groups: [
            {
              name: this.$i18n.t('DHCP used leases'),
              items: [
                {
                  title: this.$i18n.t('Numbers of ip addresses assigned'),
                  metric: 'packetfence.dhcp.used_leases',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
            {
              name: this.$i18n.t('DHCP percent used leases'),
              items: [
                {
                  title: this.$i18n.t('Percent of ip addresses used'),
                  metric: 'packetfence.dhcp.percent_used_leases',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            }
          ] // groups
        }, // DHCP section
        {
          name: this.$i18n.t('Endpoints'),
          groups: [
            {
              name: this.$i18n.t('Registered & Unregistered Devices'),
              items: [
                {
                  title: this.$i18n.t('Registration status of online devices'),
                  metric: 'packetfence.devices.registered_unregistered',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  cols: 6
                },
                {
                  title: this.$i18n.t('Devices currently registered'),
                  metric: 'statsd_gauge_source.packetfence.devices.registered',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: 'gauge'
                  },
                  cols: 6
                }
              ]
            },
            {
              name: this.$i18n.t('Registered Devices Per Role'),
              items: [
                {
                  title: this.$i18n.t('Registered devices per role'),
                  metric: 'packetfence.devices.registered_per_role',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
            {
              name: this.$i18n.t('Registered Devices Per Timeframe'),
              items: ['hour', 'day', 'week', 'month', 'year'].map(scope => {
                return {
                  title: this.$i18n.t(`New registered devices during the past ${scope}`),
                  metric: `statsd_gauge_source.packetfence.devices.registered_last_${scope}`,
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: 'gauge'
                  },
                  cols: scope === 'year' ? 12 : 6
                }
              })
            },
            {
              name: this.$i18n.t('Device Security Events'),
              items: [
                {
                  title: this.$i18n.t('Currently open security events'),
                  metric: 'statsd_gauge_source.packetfence.security_events',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: 'gauge'
                  },
                  cols: 12
                }
              ]
            }
          ] // groups
        }, // Endpoints section
        {
          name: this.$i18n.t('Portal'),
          groups: [
            {
              name: this.$i18n.t('Captive Portal Responses'),
              items: ['1xx', '2xx', '3xx', '4xx', '5xx', 'other'].map(code => {
                return {
                  title: this.$i18n.t('{http_code} responses', { http_code: code }),
                  metric: 'web_log_apache_portal_log.response_codes',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: code
                  },
                  cols: 6
                }
              })
            },
            {
              name: this.$i18n.t('Captive Portal Bandwidth'),
              items: [
                {
                  title: this.$i18n.t('Bandwidth used'),
                  metric: 'web_log_apache_portal_log.bandwidth',
                  mode: modes.LOCAL,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
            {
              name: this.$i18n.t('Captive Portal Response Time'),
              items: [
                {
                  title: this.$i18n.t('Response time'),
                  metric: 'web_log_apache_portal_log.response_time',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: 'avg'
                  },
                  cols: 12
                }
              ]
            }
          ] // groups
        }, // Portal section
        {
          name: this.$i18n.t('Queue'),
          groups: [
            {
              name: this.$i18n.t('Queue counts'),
              items: this.chartDimensions('packetfence.redis.queue_stats_count').map(queue => {
                return {
                  title: queue + ' ' + this.$i18n.t('queue count'),
                  metric: 'packetfence.redis.queue_stats_count',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: queue
                  },
                  cols: 6
                }
              })
            },
            {
              name: this.$i18n.t('Queue tasks outstanding counts'),
              items: this.chartDimensions('packetfence.redis.queue_stats_outstanding').map(task => {
                return {
                  title: task + ' ' + this.$i18n.t('outstanding'),
                  metric: 'packetfence.redis.queue_stats_outstanding',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: task.replace(/:/g, '_')
                  },
                  cols: 6
                }
              })
            },
            {
              name: this.$i18n.t('Queue tasks expired counts'),
              items: this.chartDimensions('packetfence.redis.queue_stats_expired').map(task => {
                return {
                  title: task + ' ' + this.$i18n.t('expired'),
                  metric: 'packetfence.redis.queue_stats_expired',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  params: {
                    filter_graph: task.replace(/:/g, '_')
                  },
                  cols: 6
                }
              })
            }
          ] // groups
        }, // Queue section
        {
          name: this.$i18n.t('Logs'),
          groups: [
            {
              name: 'packetfence.log',
              items: [
                {
                  title: this.$i18n.t('Number of events'),
                  metric: 'packetfence.logs.packetfence_log',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
            {
              name: 'pfdhcp.log',
              items: [
                {
                  title: this.$i18n.t('Number of events'),
                  metric: 'packetfence.logs.pfdhcp_log',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
            {
              name: 'load_balancer.log',
              items: [
                {
                  title: this.$i18n.t('Number of events'),
                  metric: 'packetfence.logs.load_balancer_log',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
            {
              name: 'radius.log',
              items: [
                {
                  title: this.$i18n.t('Number of events'),
                  metric: 'packetfence.logs.radius_log',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
            {
              name: 'mariadb_error.log',
              items: [
                {
                  title: this.$i18n.t('Number of events'),
                  metric: 'packetfence.logs.mariadb_error_log',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
            {
              name: 'pfmon.log',
              items: [
                {
                  title: this.$i18n.t('Number of events'),
                  metric: 'packetfence.logs.pfmon_log',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
            {
              name: 'fingerbank.log',
              items: [
                {
                  title: this.$i18n.t('Number of events'),
                  metric: 'packetfence.logs.fingerbank_log',
                  mode: modes.COMBINED,
                  library: libs.DYGRAPH,
                  cols: 12
                }
              ]
            },
          ] // groups
        } // Logs section
      ],
      sections: [],
      pingNetdataInterval: 1000 * 30, // ms
      alarmsInterval: 1000 * 60
    }
  },
  computed: {
    chartsError () {
      return !this.$store.state.session.charts
    },
    libs () {
      return Object.values(libs)
    },
    charts () {
      return this.$store.state[this.storeName].charts
    },
    all_modules () {
      return this.$store.getters[`${this.storeName}/allModules`]
    },
    new_chart_valid () {
      return this.new_chart.value !== null && this.new_chart.cols > 0 && this.new_chart.library !== null
    },
    cluster () {
      return this.$store.state[this.storeName].cluster
    }
  },
  methods: {
    init () {
      // Filter out empty sections
      this.sections = JSON.parse(JSON.stringify(this.allSections))
      this.sections.forEach(section => {
        let { items, groups } = section
        if (items) {
          items = items.filter(this.chartIsValid)
        }
        groups.forEach(group => {
          if ('items' in group) {
            group.items = group.items.filter(this.chartIsValid)
          }
        })
        section.groups = groups.filter(group => {
          if ('items' in group) {
            return group.items.length > 0
          }
        })
      })
      this.sections = this.sections.filter(section => ('items' in section && section.items.length) || ('groups' in section && section.groups.length))
    },
    initNetdata () {
      if (window.NETDATA) {
        // External JS library already loaded
        this.$nextTick(() => {
          window.NETDATA.parseDom()
        })
      } else {
        // Load external JS library
        let el = document.createElement('SCRIPT')
        window.netdataNoBootstrap = true
        window.netdataTheme = 'default'
        // window.netdataTheme = 'slate' #272b30
        el.setAttribute('src', `//${window.location.hostname}:${window.location.port}/netdata/127.0.0.1/dashboard.js`)
        document.head.appendChild(el)
      }
    },
    pingNetdata () {
      const [firstChart] = this.$store.state[this.storeName].allCharts
      if (firstChart) {
        // We have a list of charts; check if the first one is still available.
        // In case of an error, the interceptor will set CHART_ERROR
        this.$store.dispatch(`${this.storeName}/getChart`, firstChart.id)
        setTimeout(this.pingNetdata, this.pingNetdataInterval)
      } else {
        // No charts yet
        this.$store.dispatch('services/getService', 'netdata').then(service => {
          if (service.alive) {
            setTimeout(() => {
              this.$store.dispatch(`${this.storeName}/allCharts`).then(() => {
                this.init()
                this.initNetdata()
                setTimeout(this.pingNetdata, this.pingNetdataInterval)
              })
            }, 20000) // wait until netdata is ready
          } else {
            setTimeout(this.pingNetdata, this.pingNetdataInterval)
          }
        })
      }
    },
    getAlarms () {
      if (this.$store.state[this.storeName].allCharts) {
        this.cluster.forEach(({ management_ip: ip }) => {
          this.$store.dispatch(`${this.storeName}/alarms`, ip).then(({ hostname, alarms }) => {
            Object.keys(alarms).forEach(path => {
              const alarm = alarms[path]
              const label = alarm.chart.split('.')[0].replace(/_/g, ' ') + ' - ' + alarm.family
              const value = alarm.value_string
              let status = alarm.status.toLowerCase()
              switch (status) {
                case 'warning':
                  break
                case 'critical':
                  status = 'danger'
                  break
                default:
                  status = 'info'
              }
              const previousNotification = this.$store.state.notification.all.find(notification => {
                return notification.url === path && notification.value === value
              })
              if (!previousNotification) {
                this.$store.dispatch(`notification/${status}`, {
                  message: `<span class="font-weight-normal">${hostname}</span> ${label}`,
                  url: path,
                  value
                })
              }
            })
            setTimeout(this.getAlarms, this.alarmsInterval)
          })
        })
      } else {
        setTimeout(this.getAlarms, this.alarmsInterval)
      }
    },
    moduleCharts (module) {
      let charts = []
      for (var chart of this.$store.state[this.storeName].allCharts) {
        if ((chart.module && chart.module === module) || (!chart.module && module === 'other')) {
          charts.push(chart)
        }
      }
      return charts
    },
    chartDimensions (chart) {
      const definition = this.$store.state[this.storeName].allCharts.find(o => o.id === chart)
      if (definition) {
        const { dimensions } = definition
        return Object.values(dimensions).map(dimension => dimension.name)
      }
      return []
    },
    chartHosts (chart) {
      const { mode, params = {} } = chart
      let hosts = []
      if (mode === modes.COMBINED) {
        // Cluster data is aggregated into one chart
        hosts = [this.cluster.map(server => `/netdata/${server.management_ip}`).join(',')]
        params['friendly-host-names'] = this.cluster.map(server => `/netdata/${server.management_ip}=${server.host}`).join(',')
        chart.params = params
      } else if (mode === modes.SINGLE) {
        // Each cluster member has a chart
        hosts = this.cluster.map(server => `/netdata/${server.management_ip}`)
      } else if (mode === modes.LOCAL) {
        // Only check localhost
        hosts = ['/netdata/127.0.0.1']
      }
      return hosts
    },
    chartIsValid (chart) {
      return !!this.$store.state[this.storeName].allCharts.find(c => c.id === chart.metric)
    },
    cols (count, siblings) {
      return siblings === 1 ? 12 : (count || 6)
    },
    palette (index) {
      return palettes[index % palettes.length]
    },
    addChart (options) {
      let definition = this.$store.state[this.storeName].allCharts.find(c => c.id === options.id)
      let chart = Object.assign(definition, options)
      this.$store.dispatch(`${this.storeName}/addChart`, chart)
      this.initNetdata()
    }
  },
  created () {
    if (this.$store.state[this.storeName].allCharts) {
      this.init()
    }
    setTimeout(this.pingNetdata, this.pingNetdataInterval)
  },
  mounted () {
    if (this.$store.state[this.storeName].allCharts) {
      this.initNetdata()
      this.getAlarms()
    }
  }
}
</script>
