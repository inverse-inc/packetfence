<template>
  <b-card no-body>
    <b-card-header>
      {{ $i18n.t('Hosts') }}
    </b-card-header>
    <b-tabs small lazy>
      <b-tab v-for="host in uniqueHosts" :key="host.tld">
        <template #title>
          {{ host.tld }} <b-badge pill variant="primary" class="ml-1">{{ host.count }}</b-badge>
        </template>
        <b-row>
          <b-col cols="12">
            <base-chart-parallel
              :dimensions="dimensions(host.tld)"
              :color="color(host.tld)"
              :counts="counts(host.tld)"
              :isLoading="isLoading"
              :settings="settings"
            />
          </b-col>
        </b-row>
        <b-row>
          <b-col cols="6">
            <base-chart-grouped-bar
              :traces="perDeviceTraces(host.tld)"
              :isLoading="isLoading"
              :title="$i18n.t('Devices')"
              :settings="settings"
            />
          </b-col>
          <b-col cols="6">
            <base-chart-grouped-bar
              :traces="perProtocolTraces(host.tld)"
              :isLoading="isLoading"
              :title="$i18n.t('Protocols')"
              :settings="settings"
            />
          </b-col>
        </b-row>
      </b-tab>
    </b-tabs>
  </b-card>
</template>
<script>
import BaseChartGroupedBar from './BaseChartGroupedBar'
import BaseChartParallel from './BaseChartParallel'
const components = {
  BaseChartGroupedBar,
  BaseChartParallel,
}

import { computed, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const isLoading = computed(() => $store.getters['$_fingerbank_communication/isLoading'])
  const items = computed(() => $store.getters['$_fingerbank_communication/tabular'])

  const settings = ref({})
  $store.dispatch('preferences/get', 'settings')
    .then(() => {
      settings.value = $store.state.preferences.cache['settings'] || {}
    })

  const uniqueHosts = computed(() => {
    const assoc = items.value
      .reduce((unique, item) => {
        unique[item.tld] = (unique[item.tld] || 0) + 1
        return unique
      }, {})
    return Object.keys(assoc)
      .sort((a,b) => a.localeCompare(b))
      .map(tld => {
        return {
          tld,
          count: assoc[tld]
        }
      })
  })

  const sortedItems = computed(() => {
    return items.value.sort((a, b) => {
      return a.host - b.host
    })
  })

  const dimensions = computed(() => {
    return tld => [
      {
        label: i18n.t('Devices'),
        textposition: 'right',
        values: sortedItems.value
          .filter(item => item.tld === tld)
          .map(item => item.mac)
      },
      {
        label: i18n.t('Hosts'),
        values: sortedItems.value
          .filter(item => item.tld === tld)
          .map(item => item.host)
      },
      {
        label: i18n.t('Protocols'),
        textposition: 'left',
        values: sortedItems.value
          .filter(item => item.tld === tld)
          .map(item => item.protocol)
      }
    ]
  })

  const color = computed(() => {
    return tld => {
      return sortedItems.value
        .filter(item => item.tld === tld)
        .map(() => 'rgb(40, 167, 69)')
    }
  })

  const counts = computed(() => {
    return tld => sortedItems.value
      .filter(item => item.tld === tld)
      .map(item => item.count)
  })

  const perDeviceTraces = computed(() => {
    return tld => {
      const items = sortedItems.value.filter(item => item.tld === tld)
        .sort((a, b) => a.mac.localeCompare(b.mac))
      const distinctDevices = [...new Set(items.map(item => item.mac))]
      const distinctPorts = [...new Set(items.map(item => item.port))]
      return distinctPorts
        .sort((a, b) => a.port - b.port)
        .map(port => {
          const x = distinctDevices
          const y = distinctDevices.map(mac => items.reduce((count, item) => {
            if (item.port === port && item.mac === mac) {
              count += item.count
            }
            return count
          }, 0))
          const color = 'rgb(40, 167, 69)' // success
          return {
            x,
            y,
            text: port,
            textposition: 'auto',
            type: 'bar',
            marker: {
              color,
              line: {
                color: 'rgb(255, 255, 255)',
                width: 1
              }
            },
          }
        })
    }
  })

  const perProtocolTraces = computed(() => {
    return tld => {
      const items = sortedItems.value.filter(item => item.tld === tld)
        .sort((a, b) => a.host.localeCompare(b.host))
      const distinctProtocols = [...new Set(items.map(item => item.protocol))]
      const distinctPorts = [...new Set(items.map(item => item.port))]
      return distinctPorts
        .sort((a, b) => a.port - b.port)
        .map(port => {
          const x = distinctProtocols
          const y = distinctProtocols.map(protocol => items.reduce((count, item) => {
            if (item.port === port && item.protocol === protocol) {
              count += item.count
            }
            return count
          }, 0))
          const color = 'rgb(40, 167, 69)' // success
          return {
            x,
            y,
            text: port,
            textposition: 'auto',
            type: 'bar',
            marker: {
              color,
              line: {
                color: 'rgb(255, 255, 255)',
                width: 1
              }
            },
          }
        })
    }
  })

  return {
    isLoading,
    settings,

    uniqueHosts,

    perDeviceTraces,
    perProtocolTraces,

    dimensions,
    color,
    counts,
  }
}


// @vue/component
export default {
  name: 'base-data-hosts',
  components,
  setup
}
</script>