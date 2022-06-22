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
        @click="onSelectInverse">{{ $i18n.t('Invert') }}</b-btn>

      <b-row v-for="item in decoratedItems" :key="item.protocol"
        @click="onSelectItem(item)"
        align-h="end"
        align-v="center"
        :class="{
          'filter-selected': selectedProtocols.indexOf(item.protocol) > -1
        }">
        <b-col cols="1" class="px-0 py-1 ml-3 text-center">
          <template v-if="selectedProtocols.findIndex(v => RegExp(`^${v}:`, 'i').test(item.protocol)) > -1">
            <icon name="check-square" class="bg-white text-success" scale="1.125" style="opacity: 0.25;" />
          </template>
          <template v-else-if="selectedProtocols.indexOf(item.protocol) > -1">
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
          <text-highlight :queries="[filter]">{{ item.protocol }}</text-highlight>
        </b-col>
        <b-col cols="auto mr-3">
          <b-badge v-if="item._num_devices"
            class="ml-1">{{ item._num_devices }} {{ $i18n.t('devices') }}</b-badge>
          <b-badge v-if="item._num_hosts"
            class="ml-1">{{ item._num_hosts }} {{ $i18n.t('hosts') }}</b-badge>
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
import { decorateProtocol, splitProtocol, useProtocols } from '../_composables/useCommunication'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const isLoading = computed(() => $store.getters['$_fingerbank_communication/isLoading'])
  const protocols = computed(() => useProtocols($store.state.$_fingerbank_communication.cache))
  const selectedProtocols = computed(() => $store.state.$_fingerbank_communication.selectedProtocols)

  const items = computed(() => {
    return Object.keys(protocols.value)
      .map(item => {
        const { proto, port } = splitProtocol(item)
        const protocol = decorateProtocol(item)
        return { proto, port, protocol }
      })
      .sort((a, b) => {
        if (a.proto === b.proto) {
          return a.port - b.port
        }
        return a.proto.toLowerCase().localeCompare(b.proto.toLowerCase())
      })
  })

  const filter = ref('')

  const filteredItems = computed(() => {
    if (!filter.value) {
      return items.value
    }
    return items.value
      .filter(item => (item.proto.toLowerCase().indexOf(filter.value.toLowerCase()) > -1 || `${item.port}`.indexOf(filter.value) > -1))
  })

  const decoratedItems = computed(() => {
    const decorated = []
    let lastProto
    for(let i = 0; i < filteredItems.value.length; i++) {
      const item = filteredItems.value[i]
      const { proto, protocol } = item
      const _num_devices = Object.keys(protocols.value[protocol].devices).length
      const _num_hosts = Object.keys(protocols.value[protocol].hosts).length
      if (lastProto !== proto) {
        lastProto = proto
        if (i > 0) {
          decorated[decorated.length - 1]._tree[0].name = 'tree-last'
        }
        // push pseudo category
        decorated.push({ protocol: proto })
      }
      decorated.push({
        ...item,
        protocol,
        _num_devices,
        _num_hosts,
        _tree: [
          { name: 'tree-node', class: 'nav-icon' }
        ]
      })
    }
    if (decorated.length > 0) {
      decorated[decorated.length - 1]._tree[0].name = 'tree-last'
    }
    return decorated
  })

  const onSelectItem = item => {
    $store.dispatch('$_fingerbank_communication/toggleProtocol', item.protocol)
  }

  const onSelectAll = () => {
    $store.dispatch('$_fingerbank_communication/selectProtocols', decoratedItems.value
      .filter(item => !item.port) // skip ports
      .map(item => item.protocol)
    )
  }

  const onSelectNone = () => {
    $store.dispatch('$_fingerbank_communication/deselectProtocols', decoratedItems.value.map(item => item.protocol))
  }

  const onSelectInverse = () => {
    $store.dispatch('$_fingerbank_communication/invertProtocols', decoratedItems.value.map(item => item.protocol))
  }

  return {
    isLoading,
    filter,
    selectedProtocols,
    decoratedItems,
    onSelectItem,
    onSelectAll,
    onSelectNone,
    onSelectInverse,
  }
}

// @vue/component
export default {
  name: 'base-filter-protocols',
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