<template>
  <b-card no-body>
    <b-card-header>
      Protocols
    </b-card-header>
    <b-tabs small lazy>
      <b-tab v-for="protocol in uniqueProtocols" :key="protocol.proto">
        <template #title>
          {{ protocol.proto }} <b-badge pill variant="primary" class="ml-1">{{ protocol.num }}</b-badge>
        </template>
        <b-row>
          <b-col cols="6">
            <base-chart-grouped-bar
              :traces="perDeviceTraces(protocol.proto)"
              :isLoading="isLoading"
              :title="$i18n.t('Per {proto} Device', protocol)"
              :settings="settings"
            />
          </b-col>
          <b-col cols="6">
            <base-chart-grouped-bar
              :traces="perHostTraces(protocol.proto)"
              :isLoading="isLoading"
              :title="$i18n.t('Per {proto} Host', protocol)"
              :settings="settings"
            />
          </b-col>
        </b-row>
        <b-row>
          <b-col cols="12">
            <base-chart-parallel
              :dimensions="dimensions(protocol.proto)"
              :color="color(protocol.proto)"
              :counts="counts(protocol.proto)"
              :isLoading="isLoading"
              :title="$i18n.t('{proto} Ports', protocol)"
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

const props = {
  items: {
    type: Array
  },
  isLoading: {
    type: Boolean
  }
}

import { computed, ref, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { useSearch } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const settings = ref({})
  $store.dispatch('preferences/get', 'settings')
    .then(() => {
      settings.value = $store.state.preferences.cache['settings'] || {}
    })

  const {
    items,
    isLoading
  } = toRefs(props)

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
            num: assoc[proto]
          }
        })
  })

  const uniqueProtocolPortsPerDevice = computed(() => {
    return items.value
      .reduce((unique, item) => {
        const { proto, port, host, mac } = item
        if (!(proto in unique))
          unique[proto] = {}
        if (!(port in unique[proto]))
          unique[proto][port] = {}
        if (!(mac in unique[proto][port]))
          unique[proto][port][mac] = 1
        else
          unique[proto][port][mac]++
        return unique
      }, {})
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
        label: i18n.t('{proto} Ports', { proto }),
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
      .map(() => 1)
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
          const y = distinctDevices.map(mac => items.filter(item => item.port === port && item.mac === mac).length)
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
          const y = distinctHosts.map(host => items.filter(item => item.port === port && item.host === host).length)
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
    settings,

    uniqueProtocols,
    uniqueProtocolPortsPerDevice,

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
  props,
  setup
}
</script>