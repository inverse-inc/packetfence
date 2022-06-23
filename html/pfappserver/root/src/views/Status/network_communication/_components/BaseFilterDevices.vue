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

      <b-row v-for="item in filteredItems" :key="item.mac"
        @click="onSelectItem(item)"
        align-v="center"
        :class="{
          'filter-selected': selectedDevices.indexOf(item.mac) > -1
        }">
        <b-col cols="1" class="px-3 py-1 ml-3 text-center">
          <template v-if="selectedDevices.indexOf(item.mac) > -1">
            <icon name="check-square" class="bg-white text-success" scale="1.125" />
          </template>
          <template v-else>
            <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
          </template>
        </b-col>
        <b-col cols="auto mr-auto text-mono" class="px-3 py-1 mr-3">
          <text-highlight :queries="[filter]">{{ item.mac }}</text-highlight>
        </b-col>
        <b-col cols="auto mr-3">
          <b-badge v-if="byDevice[item.mac]"
            class="ml-1">{{ Object.keys(byDevice[item.mac].hosts).length }} {{ $i18n.t('hosts') }}</b-badge>
          <b-badge v-if="byDevice[item.mac]"
            class="ml-1">{{ Object.keys(byDevice[item.mac].protocols).length }} {{ $i18n.t('protocols') }}</b-badge>
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

import { computed, ref, toRefs } from '@vue/composition-api'
import { useNodesSearch } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const search = useNodesSearch()
  const {
    items
  } = toRefs(search)

  const selectedDevices = computed(() => $store.state.$_fingerbank_communication.selectedDevices.value)
  const byDevice = computed(() => $store.getters['$_fingerbank_communication/byDevice'])

  const uniqueItems = computed(() => {
    return items.value
      .reduce((unique, item) => {
        if (unique.filter(u => u.mac === item.mac).length === 0) {
          return [ ...unique, item ]
        }
        return unique
      }, [])
      .sort((a, b) => a.mac.localeCompare(b.mac))
  })

  const filter = ref('')

  const filteredItems = computed(() => {
    if (!filter.value) {
      return uniqueItems.value
    }
    return uniqueItems.value
      .filter(item => (item.mac.indexOf(filter.value) > -1))
  })

  const onSelectItem = item => {
    $store.dispatch('$_fingerbank_communication/toggleDevice', item.mac)
  }

  const onSelectAll = () => {
    $store.dispatch('$_fingerbank_communication/selectDevices', filteredItems.value.map(item => item.mac))
  }

  const onSelectNone = () => {
    $store.dispatch('$_fingerbank_communication/deselectDevices', selectedDevices.value)
  }

  const onSelectInverse = () => {
    $store.dispatch('$_fingerbank_communication/invertDevices', filteredItems.value.map(item => item.mac))
  }

  return {
    filter,
    filteredItems,
    uniqueItems,

    selectedDevices,
    byDevice,

    onSelectItem,
    onSelectAll,
    onSelectNone,
    onSelectInverse,
  }
}

// @vue/component
export default {
  name: 'base-filter-devices',
  components,
  directives,
  setup
}
</script>