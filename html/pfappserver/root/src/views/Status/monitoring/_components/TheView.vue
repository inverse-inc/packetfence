<template>
  <b-container fluid>
    <b-alert variant="danger" :show="chartsError" fade>
      <h4 class="alert-heading" v-t="'Error'"></h4>
      <p>{{ $t('The charts on the dashboard are currently not available.') }}</p>
      <base-button-service v-can:read="'services'"
        service="netdata" restart start stop class="mr-1" />
    </b-alert>
    <b-modal v-model="showChartModal"
      @shown="onShownChartModal"
      @hidden="onHiddenChartModal"
      size="xl" modal-class="modal-fullscreen" body-class="p-0"
      hide-footer
    >
      <template v-slot:modal-title>
        {{ showChartTitle }} <b-badge class="ml-1" variant="light">{{ showChart.metric }}</b-badge>
      </template>
      <template v-slot:default>
        <b-row class="align-items-center mt-3 mx-3" align-h="end">
          <small class="mx-3">{{ $t('Show Last') }}</small>
          <b-button-group size="sm" class="mr-3">
            <b-button v-for="period in periods" :key="period.text"
              :variant="(showAfter == period.value) ? 'primary' : 'light'" @click="showAfter = period.value" v-b-tooltip.hover.bottom.d300 :title="period.title">{{ period.text }}</b-button>
          </b-button-group>
          <b-button-group size="sm">
            <b-dropdown right variant="success" size="sm">
              <template v-slot:button-content>
                Netdata Cloud<icon name="external-link-alt" class="mx-1" />
              </template>
              <b-dropdown-text><small>{{ $t('Choose Host') }}</small></b-dropdown-text>
              <b-dropdown-divider/>
              <b-dropdown-item v-for="({ management_ip, host}) in cluster" :key="management_ip"
                :href="`/netdata/${management_ip}/`" target="_blank">{{ host }}</b-dropdown-item>
            </b-dropdown>
          </b-button-group>
        </b-row>
        <b-row align-h="center" align-v="center" :key="`${showChart.metric}-${showAfter}-modal`">
          <b-col md="12" v-for="({ management_ip, host}) in cluster" :key="management_ip">
            <div class="p-3">
              <small class="text-muted">{{ host }}</small>
              <div class="mt-2">
                <chart :definition="{ ...showChart, height: `${Math.max(20, 75 / Object.keys(cluster).length)}vh` }" :host="`/netdata/${management_ip}`" :data-colors="palette(0)"
                  :data-common-max="showChart.metric" :data-common-units="showChart.metric" :data-after="-showAfter" />
              </div>
            </div>
          </b-col>
        </b-row>
      </template>
    </b-modal>

    <b-row class="align-items-center mb-3">
      <b-col cols="4" align-h="start">
        <b-input-group class="flex-grow-1">
          <b-form-input v-model="filter"
            :placeholder="$i18n.t('Filter Metrics')" />
          <template v-slot:append>
            <b-button
              :disabled="filter==''"
              tabIndex="-1"
              @click="filter = ''"
            >
              <icon name="times"/>
            </b-button>
          </template>
        </b-input-group>
      </b-col>
      <b-col cols="8" align="end">
        <small class="mx-3">{{ $t('Show Last') }}</small>
        <b-button-group size="sm" class="mr-3">
          <b-button v-for="period in periods" :key="period.text"
            :variant="(showAfter == period.value) ? 'primary' : 'light'" @click="showAfter = period.value" v-b-tooltip.hover.bottom.d300 :title="period.title">{{ period.text }}</b-button>
        </b-button-group>
        <b-button-group size="sm">
          <b-dropdown right variant="success" size="sm">
            <template v-slot:button-content>
              Netdata Cloud <icon name="external-link-alt" class="mx-1" />
            </template>
            <b-dropdown-text><small>{{ $t('Choose Host') }}</small></b-dropdown-text>
            <b-dropdown-divider/>
            <b-dropdown-item v-for="({ management_ip, host: memberHost }) in cluster" :key="management_ip"
              :href="`/netdata/${management_ip}/`" target="_blank"
              :active="memberHost == host">{{ host }}</b-dropdown-item>
          </b-dropdown>
        </b-button-group>
      </b-col>
    </b-row>

    <b-tabs nav-class="nav-fill" v-model="tabIndex" lazy :key="`${host}-${$i18n.locale}`">
      <b-tab v-for="(section, sectionIndex) in filteredSections" :title="$i18n.t(section.name)" :key="`${section.name}-${sectionIndex}-${showAfter}`">
        <template v-for="(group, groupIndex) in section.groups">
          <!-- Named groups are rendered inside a card -->
          <component :is="group.name ? 'b-card' : 'div'" class="mt-3" :key="`${group.name}-${groupIndex}`" :title="$i18n.t(group.name)">
            <b-row align-h="center">
              <b-col class="mt-3 chart" v-for="(chart, chartIndex) in group.items" :key="`${chart.metric}-${chartIndex}-main`" :md="cols(chart.cols, group.items.length)">
                <small class="text-muted cursor-pointer pb-3" @click="chartZoom(section, group, chart)" v-b-tooltip.hover.bottom.d300 :title="chart.metric">
                  <icon name="expand" class="text-primary mr-1" @click="chartZoom(section, group, chart)" />
                  {{ chart.title }} <b-badge class="float-right ml-1" variant="light">{{ chart.metric }}</b-badge>
                </small>
                <div class="mt-2">
                  <chart :definition="chart" :host="`/netdata/${ip}`" :data-colors="palette(0)"
                    :data-after="-showAfter" :data-before="0" />
                </div>
              </b-col>
            </b-row>
          </component>
        </template>
      </b-tab>
    </b-tabs>
  </b-container>
</template>

<script>
import Badge from './Badge'
import Chart, { palettes } from './Chart'
import {
  BaseButtonService
} from '@/components/new/'

const components = {
  Badge,
  Chart,
  BaseButtonService
}

const props = {
  host: {
    type: String
  }
}

import { computed, nextTick, onBeforeUnmount, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import allSections from '../_config'

const setup = (props, context) => {

  const {
    host
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const ip = computed(() => {
    Object.values(cluster.value).map(({ host: _host, management_ip }) => {
      if(_host === host.value) return management_ip
    })
    const { 0: { management_ip = '127.0.0.1' } = {} } = Object.values(cluster.value)
    return management_ip
  })

  const tabIndex = ref(0)
  const tabCurrent = ref(0)
  const pingNetdataTimer = ref(false)
  const pingNetdataInterval = ref(30 * 1E3) // 30s
  const getAlarmsTimer = ref(false)
  const alarmsInterval = ref(60 * 1E3) // 60s

  const chartsError = computed(() => !$store.state.session.charts)
  const cluster = computed(() => $store.state.cluster.servers)

  const filter = ref('')
  const filteredSections = computed(() => { // filter out empty sections
    const isValid = chart => {
      if (filter.value) {
        const { metric, title } = chart
        let re = new RegExp(filter.value, 'g')
        if ( ! (re.test(metric) || re.test(title))) {
          return false
        }
      }
      const uniqueCharts = $store.getters[`$_status/uniqueCharts`]
      return uniqueCharts && !!uniqueCharts.find(c => c.id === chart.metric)
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
      // window.netdataTheme = 'slate' // #272b30
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
      $store.dispatch('cluster/getService', { server: $store.state.system.hostname, id: 'netdata' }).then(service => {
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
      Object.values(cluster.value).forEach(({ management_ip: ip }) => {
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

  const showChartModal = ref(false)
  const showChart = ref(false)
  const showChartTitle = ref(false)
  const chartZoom = (section, group, chart) => {
    showChartModal.value = true
    showChart.value = chart
    showChartTitle.value = (section.name !== group.name)
      ? `${i18n.t(section.name)} - ${i18n.t(group.name)} - ${i18n.t(chart.title)}`
      : `${i18n.t(section.name)} - ${i18n.t(chart.title)}`
  }
  const onShownChartModal = () => {
    nextTick(() => {
      window.NETDATA.updatedDom()
    })
  }
  const onHiddenChartModal = () => {}

  const showAfter = ref(60 * 60)
  const periods = [
    { title: i18n.t('5 minutes'),  text: '5m', value: 60 * 5 },
    { title: i18n.t('15 minutes'), text: '15m', value: 60 * 15 },
    { title: i18n.t('30 minutes'), text: '30m', value: 60 * 30 },
    { title: i18n.t('1 hour'),     text: '1h',  value: 60 * 60 },
    { title: i18n.t('2 hours'),    text: '2h',  value: 60 * 60 * 2 },
    { title: i18n.t('6 hours'),    text: '6h',  value: 60 * 60 * 6 },
    { title: i18n.t('12 hours'),   text: '12h', value: 60 * 60 * 12 },
    { title: i18n.t('24 hours'),   text: '24h',  value: 60 * 60 * 24 },
    { title: i18n.t('2 days'),     text: '2D',  value: 60 * 60 * 24 * 2 },
    { title: i18n.t('4 days'),     text: '4D',  value: 60 * 60 * 24 * 4 },
    { title: i18n.t('1 week'),     text: '1W',  value: 60 * 60 * 24 * 7 },
    { title: i18n.t('2 weeks'),    text: '2W',  value: 60 * 60 * 24 * 14 },
    { title: i18n.t('28 days'),    text: '28D',  value: 60 * 60 * 24 * 28 }
  ]

  watch([tabIndex, () => i18n.locale, showAfter, filter], () => {
    nextTick(() => {
      window.NETDATA.updatedDom()
    })
  })

  watch(tabIndex, () => {
    tabCurrent.value = filteredSections.value[tabIndex.value].name
  }, { immediate:true })

  watch(filteredSections, () => {
    nextTick(() => {
      tabIndex.value = Math.max(0, filteredSections.value.findIndex(f => f.name == tabCurrent.value))
    })
  })

  return {
    filter,
    filteredSections,
    tabIndex,
    chartsError,
    chartZoom,
    cluster,
    cols,
    palette,
    ip,
    showChartModal,
    showChart,
    showChartTitle,
    onShownChartModal,
    onHiddenChartModal,

    showAfter,
    periods,
    location: window.location
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  props,
  setup
}
</script>
