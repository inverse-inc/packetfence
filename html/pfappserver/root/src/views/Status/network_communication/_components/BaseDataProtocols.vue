<template>
  <b-card no-body>
    <b-card-header>
      {{ $i18n.t('Protocols') }}
    </b-card-header>
    <b-tabs small lazy>
      <b-tab v-for="protocol in uniqueProtocols" :key="protocol.proto">
        <template #title>
          {{ protocol.proto }} <b-badge pill variant="primary" class="ml-1">{{ protocol.count }}</b-badge>
        </template>
        <b-row>
          <b-col cols="12">
            <base-chart-parallel
              :dimensions="dimensions(protocol.proto)"
              :color="color(protocol.proto)"
              :counts="counts(protocol.proto)"
              :isLoading="isLoading"
              :settings="settings"
            />
          </b-col>
        </b-row>
        <b-row>
          <b-col cols="6">
            <base-chart-grouped-bar
              :traces="perDeviceTraces(protocol.proto)"
              :isLoading="isLoading"
              :title="$i18n.t('Devices')"
              :settings="settings"
            />
          </b-col>
          <b-col cols="6">
            <base-chart-grouped-bar
              :traces="perHostTraces(protocol.proto)"
              :isLoading="isLoading"
              :title="$i18n.t('Hosts')"
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

  const uniqueProtocols = computed(() => {
    const assoc = items.value
      .reduce((unique, item) => {
        unique[item.proto] = (unique[item.proto] || 0) + 1
        return unique
      }, {})
    return Object.keys(assoc)
      .sort((a,b) => a.localeCompare(b))
      .map(proto => {
        return {
          proto,
          count: assoc[proto]
        }
      })
  })

  const sortedItems = computed(() => {
    return items.value.sort((a, b) => {
      return a.port - b.port
    })
  })

  const dimensions = computed(() => {
    return proto => [
      {
        label: i18n.t('Devices'),
        values: sortedItems.value
          .filter(item => item.proto === proto)
          .map(item => item.mac)
      },
      {
        label: i18n.t('Ports'),
        values: sortedItems.value
          .filter(item => item.proto === proto)
          .map(item => item.port)
      },
      {
        label: i18n.t('Hosts'),
        values: sortedItems.value
          .filter(item => item.proto === proto)
          .map(item => item.host)
      }
    ]
  })

  const color = computed(() => {
    return proto => {
      return sortedItems.value
        .filter(item => item.proto === proto)
        .map(item => {
          switch (true) {
            case (+item.port < 1024):
              return 'rgb(40, 167, 69)' // success
              // break
            case (+item.port < 49152):
                return 'rgb(255, 193, 7)' // warning
              // break
            default:
              return 'rgb(220, 53, 69)' // danger
          }
        })
    }
  })

  const counts = computed(() => {
    return proto => sortedItems.value
      .filter(item => item.proto === proto)
      .map(item => item.count)
  })

  const perDeviceTraces = computed(() => {
    return proto => {
      const items = sortedItems.value.filter(item => item.proto === proto)
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
          const color = (() => {
            switch (true) {
              case (+port < 1024):
                return 'rgb(40, 167, 69)' // success
                // break
              case (+port < 49152):
                  return 'rgb(255, 193, 7)' // warning
                // break
              default:
                return 'rgb(220, 53, 69)' // danger
            }
          })()
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

  const perHostTraces = computed(() => {
    return proto => {
      const items = sortedItems.value.filter(item => item.proto === proto)
        .sort((a, b) => a.host.localeCompare(b.host))
      const distinctHosts = [...new Set(items.map(item => item.host))]
      const distinctPorts = [...new Set(items.map(item => item.port))]
      return distinctPorts
        .sort((a, b) => a.port - b.port)
        .map(port => {
          const x = distinctHosts
          const y = distinctHosts.map(host => items.reduce((count, item) => {
            if (item.port === port && item.host === host) {
              count += item.count
            }
            return count
          }, 0))
          const color = (() => {
            switch (true) {
              case (+port < 1024):
                return 'rgb(40, 167, 69)' // success
                // break
              case (+port < 49152):
                  return 'rgb(255, 193, 7)' // warning
                // break
              default:
                return 'rgb(220, 53, 69)' // danger
            }
          })()
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

    uniqueProtocols,

    perDeviceTraces,
    perHostTraces,

    dimensions,
    color,
    counts,
  }
}


// @vue/component
export default {
  name: 'base-data-protocols',
  components,
  setup
}
</script>