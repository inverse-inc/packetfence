<template>
    <b-container class="my-3" fluid>
      <b-alert variant="danger" :show="chartsError" fade>
        <h4 class="alert-heading" v-t="'Error'"></h4>
        <p>{{ $t('The charts of the dasboard are currently not available.') }}</p>
        <base-button-service v-can:read="'services'"
          service="netdata" restart start stop class="mr-1" />
      </b-alert>
      <b-tabs nav-class="nav-fill" v-model="tabIndex" lazy :key="$i18n.locale">
        <b-tab v-for="(section, sectionIndex) in filteredSections" :title="$i18n.t(section.name)" :key="`${section.name}-${sectionIndex}`">
          <b-row align-h="center" v-if="sectionIndex === 0"><!-- Show uptime on first tab only -->
            <b-col class="mt-3 text-center" :md="Math.max(parseInt(12/cluster.length), 3)" v-for="({ management_ip, host}, i) in cluster" :key="management_ip">
              <badge :ip="management_ip" :chart="'system.uptime'" :label="`${host} - uptime`" :colors="palette(i)" />
            </b-col>
          </b-row>
          <template v-for="(group, groupIndex) in section.groups">
            <!-- Named groups are rendered inside a card -->
            <component :is="group.name ? 'b-card' : 'div'" class="mt-3" :key="`${group.name}-${groupIndex}`" :title="$i18n.t(group.name)">
              <b-row align-h="center">
                <template v-for="(chart, chartIndex) in group.items">
                <b-col class="mt-3" :md="cols(chart.cols, group.items.length)" v-for="(host, index) in chartHosts(chart)" :key="`${chart.metric}${host}-${chartIndex}`">
                  <chart store-name="$_status" :definition="chart" :host="host" :data-colors="palette(index)"></chart>
                </b-col>
                </template>
              </b-row>
            </component>
          </template>
        </b-tab>
      </b-tabs>
  </b-container>
</template>

<script>
import Badge from './Badge'
import Chart, { modes, palettes } from './Chart'
import {
  BaseButtonService
} from '@/components/new/'

const components = {
  Badge,
  Chart,
  BaseButtonService
}

import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import allSections from '../_config'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const tabIndex = ref(0)
  const pingNetdataTimer = ref(false)
  const pingNetdataInterval = ref(30 * 1E3) // 30s
  const getAlarmsTimer = ref(false)
  const alarmsInterval = ref(60 * 1E3) // 60s

  const chartsError = computed(() => !$store.state.session.charts)
  const cluster = computed(() => ($store.state['$_status'].cluster || []))
  const filteredSections = computed(() => { // filter out empty sections
    const isValid = chart => {
      return !!$store.getters[`$_status/uniqueCharts`].find(c => c.id === chart.metric)
    }
    const sections = JSON.parse(JSON.stringify(allSections))
    sections.forEach(section => {
      let { items, groups } = section
      if (items)
        section.items = items.filter(isValid)
      groups.forEach(group => {
        if ('items' in group)
          group.items = group.items.filter(isValid)
      })
      section.groups = groups.filter(group => {
        if ('items' in group)
          return group.items.length > 0
      })
    })
    return sections.filter(section => ('items' in section && section.items.length) || ('groups' in section && section.groups.length))
  })

  const initNetdata = () => {
    if (window.NETDATA) {
      // External JS library already loaded
      nextTick(() => {
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
  }

  const pingNetdata = () => {
    const [firstChart] = $store.getters[`$_status/uniqueCharts`]
    if (firstChart) {
      // We have a list of charts; check if the first one is still available.
      // In case of an error, the interceptor will set CHART_ERROR
      $store.dispatch(`$_status/getChart`, firstChart.id)
      pingNetdataTimer.value = setTimeout(pingNetdata, pingNetdataInterval.value)
    } else if (acl.$can('read', 'services')) {
      // No charts yet
      $store.dispatch('services/getService', 'netdata').then(service => {
        if (service.alive) {
          setTimeout(() => {
            $store.dispatch(`$_status/allCharts`).then(() => {
              initNetdata()
              pingNetdataTimer.value = setTimeout(pingNetdata, pingNetdataInterval.value)
            })
          }, 20000) // wait until netdata is ready
        } else {
          pingNetdataTimer.value = setTimeout(pingNetdata, pingNetdataInterval.value)
        }
      })
    }
  }
  pingNetdataTimer.value = setTimeout(pingNetdata, pingNetdataInterval.value)

  const getAlarms = () => {
    if ($store.state['$_status'].allCharts) {
      cluster.value.forEach(({ management_ip: ip }) => {
        $store.dispatch(`$_status/alarms`, ip).then(({ hostname, alarms = {} } = {}) => {
          Object.keys(alarms).forEach(url => {
            const alarm = alarms[url]
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
            const previousNotification = $store.state.notification.all.find(notification => {
              return notification.url === url && notification.value === value
            })
            if (!previousNotification) {
              $store.dispatch(`notification/${status}`, {
                message: `<span class="font-weight-normal">${hostname}</span> ${label}`,
                url,
                value
              })
            }
          })
          getAlarmsTimer.value = setTimeout(getAlarms, alarmsInterval.value)
        })
      })
    } else {
      getAlarmsTimer.value = setTimeout(getAlarms, alarmsInterval.value)
    }
  }

  const chartHosts = chart => {
    const { metric, mode, params = {} } = chart
    let hosts = []
    if (mode === modes.COMBINED) {
      // Cluster data is aggregated into one chart
      hosts = [$store.getters[`$_status/hostsForChart`](metric).map(host => `/netdata/${host}`).join(',')]
      params['friendly-host-names'] = cluster.value.filter(server => {
        return $store.getters[`$_status/hostsForChart`](metric).includes(server.management_ip)
      }).map(server => {
        return `/netdata/${server.management_ip}=${server.host}`
      }).join(',')
      chart.params = params
    } else if (mode === modes.SINGLE) {
      // Each cluster member has a chart
      hosts = $store.getters[`$_status/hostsForChart`](metric).map(host => `/netdata/${host}`)
    } else if (mode === modes.LOCAL) {
      // Only check localhost
      hosts = ['/netdata/127.0.0.1']
    }
    return hosts
  }

  const cols = (count, siblings) => {
    return siblings === 1 ? 12 : (count || 6)
  }

  const palette = index => {
    return palettes[index % palettes.length]
  }

  onMounted(() => {
    if ($store.state['$_status'].allCharts) {
      initNetdata()
      getAlarms()
    }
  })

  onBeforeUnmount(() => {
    if (pingNetdataTimer.value)
      clearTimeout(pingNetdataTimer.value)
    if (getAlarmsTimer.value)
      clearTimeout(getAlarmsTimer.value)
  })

  watch([tabIndex, () => i18n.locale], () => {
    nextTick(() => {
      window.NETDATA.parseDom()
    })
  })

  return {
    filteredSections,
    tabIndex,
    chartsError,
    chartHosts,
    cluster,
    cols,
    palette
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  setup
}
</script>
