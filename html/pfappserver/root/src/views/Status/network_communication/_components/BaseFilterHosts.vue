<template>
  <b-card no-body>
    <b-card-header>
      <b-form>
        <b-input-group>
          <b-form-input v-model="filter" v-focus
            class="border-0" type="text" :placeholder="$t('Filter')" />
          <b-input-group-append v-if="filter">
            <b-btn @click="filter = ''"><icon name="times-circle" /></b-btn>
          </b-input-group-append>
        </b-input-group>
      </b-form>
    </b-card-header>
    <div class="p-0 filtered-items">
      <b-btn variant="link" size="sm" class="text-secondary"
        @click="onSelectAll">{{ $i18n.t('All') }}</b-btn>
      <b-btn variant="link" size="sm" class="text-secondary"
        @click="onSelectNone">{{ $i18n.t('None') }}</b-btn>
      <b-btn variant="link" size="sm" class="text-secondary"
        @click="onSelectInverse">{{ $i18n.t('Inverse') }}</b-btn>

      <b-row v-for="item in decoratedItems" :key="item.host"
        @click="onSelectItem(item)"
        align-h="end"
        align-v="center"
        :class="{
          'filter-selected': selectedHosts.indexOf(item.host) > -1
        }">
        <b-col cols="1" class="px-0 py-1 ml-3 text-center">
          <template v-if="selectedHosts.findIndex(v => RegExp(`\.${v}$`, 'i').test(item.host)) > -1">
            <icon name="check-square" class="bg-white text-success" scale="1.125" style="opacity: 0.25;" />
          </template>
          <template v-else-if="selectedHosts.indexOf(item.host) > -1">
            <icon name="check-square" class="bg-white text-success" scale="1.125" />
          </template>
          <template v-else>
            <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
          </template>
        </b-col>
        <b-col cols="auto mr-auto" class="px-0 mr-3">
          <div class="d-inline align-items-center mr-1">
            <icon v-for="(icon, i) in item._tree" :key="i"
              v-bind="icon" />
          </div>
          <text-highlight :queries="[filter]">{{ item.host }}</text-highlight>
        </b-col>
        <b-col cols="auto mr-3">
          <b-badge v-if="item._num_devices"
            class="ml-1">{{ item._num_devices }} {{ $i18n.t('devices') }}</b-badge>
          <b-badge v-if="item._num_protocols"
            class="ml-1">{{ item._num_protocols }} {{ $i18n.t('protocols') }}</b-badge>
        </b-col>
      </b-row>
    </div>
  </b-card>
</template>

<script>
import TextHighlight from 'vue-text-highlight'
const components = {
  TextHighlight
}

import { focus } from '@/directives'
const directives = {
  focus
}

import { computed, ref } from '@vue/composition-api'
import { decorateHost, splitHost, useHosts } from '../_composables/useCommunication'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const isLoading = computed(() => $store.getters['$_fingerbank_communication/isLoading'])
  const hosts = computed(() => useHosts($store.state.$_fingerbank_communication.cache))
  const selectedHosts = computed(() => $store.state.$_fingerbank_communication.selectedHosts)

  const items = computed(() => {
    return Object.keys(hosts.value)
      .map(item => {
        const { tld, domain, subdomain, internalHost } = splitHost(item)
        const host = decorateHost(item)
        return { tld, domain, subdomain, host, internalHost }
      })
      .sort((a, b) => {
        if (a.internalHost !== b.internalHost) {
          return b.internalHost - a.internalHost
        }
        const hostsA = (a.internalHost)
          ? a.host.split('.')
          : a.host.split('.').reverse()
        const hostsB = (b.internalHost)
          ? b.host.split('.')
          : b.host.split('.').reverse()
        for (let h = 0; h <= Math.min(hostsA.length, hostsB.length); h++) {
          if (hostsA.length <= h) {
            return -1
          }
          if (hostsB.length <= h) {
            return 1
          }
          if (hostsA[h] !== hostsB[h]) {
            return hostsA[h].localeCompare(hostsB[h])
          }
        }
      })
  })

  const filter = ref('')

  const filteredItems = computed(() => {
    if (!filter.value) {
      return items.value
    }
    return items.value
      .filter(item => (item.host.indexOf(filter.value) > -1))
  })

  const decoratedItems = computed(() => {
    const decorated = []
    let lastHostName
    for(let i = 0; i < filteredItems.value.length; i++) {
      const item = filteredItems.value[i]
      let { tld, domain, host } = item
      host = host.toLowerCase()
      const _num_devices = Object.keys(hosts.value[host].devices).length
      const _num_protocols = Object.keys(hosts.value[host].protocols).length
      const hostName = ((domain) ? `${domain}.` : '') + tld
      if (lastHostName !== hostName) {
        lastHostName = hostName
        if (i > 0 && '_tree' in decorated[decorated.length - 1]) {
          decorated[decorated.length - 1]._tree[0].name = 'tree-last'
        }
        // push pseudo category
        decorated.push({ host: hostName })
        if (host === hostName) { // no subdomains
          continue
        }
      }
      if (host.indexOf(tld) > 0) {
        decorated.push({
          ...item,
          host,
          _num_devices,
          _num_protocols,
          _tree: [
            { name: 'tree-node', class: 'nav-icon' }
          ]
        })
      }
    }
    if (decorated.length > 0 && '_tree' in decorated[decorated.length - 1]) {
      decorated[decorated.length - 1]._tree[0].name = 'tree-last'
    }
    return decorated
  })

  const onSelectItem = item => {
    $store.dispatch('$_fingerbank_communication/toggleHost', item.host)
  }

  const onSelectAll = () => {
    $store.dispatch('$_fingerbank_communication/selectHosts', decoratedItems.value
      .filter(item => !item.subdomain) // skip subdomains
      .map(item => item.host)
    )
  }

  const onSelectNone = () => {
    $store.dispatch('$_fingerbank_communication/deselectHosts', selectedHosts.value)
  }

  const onSelectInverse = () => {
    $store.dispatch('$_fingerbank_communication/invertHosts', decoratedItems.value.map(item => item.host))
  }


  return {
    isLoading,
    filter,
    selectedHosts,
    decoratedItems,
    onSelectItem,
    onSelectAll,
    onSelectNone,
    onSelectInverse,

items
  }
}

// @vue/component
export default {
  name: 'base-filter-hosts',
  components,
  directives,
  setup
}
</script>

<style lang="scss">
$table-cell-height: 1.875 * $spacer !default;

.card {
  .row {
    .col-auto {
      svg.fa-icon:not(.nav-icon) {
        min-width: $table-cell-height;
        height: auto;
        max-height: $table-cell-height/2;
        margin: 0.25rem 0;
      }
      svg.nav-icon {
        height: $table-cell-height;
        color: $gray-500;
      }
    }
  }
}
</style>