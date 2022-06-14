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

      <b-row v-for="item in filteredItems" :key="item.id"
        @click="onSelectItem(item)"
        align-v="center"
        class="mx-1 mt-1 text-nowrap border border-1 cursor-pointer"
        :class="(selectedSecurityEvents.indexOf(item.id) > -1) ? `border-${item._class}` : ''"
      >
        <b-col cols="1" class="px-3 py-3 text-center">
          <template v-if="selectedSecurityEvents.indexOf(item.id) > -1">
            <icon name="check-square" :class="`bg-white text-${item._class}`" scale="1.125" />
          </template>
          <template v-else>
            <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
          </template>
        </b-col>
        <b-col cols="auto" class="px-3 py-3">
          <text-highlight :queries="[filter]">{{ item.desc }}</text-highlight>
        </b-col>
<!--
        <b-col cols="auto">
          <b-badge v-if="byDevice[item.mac]"
            class="ml-1">{{ Object.keys(byDevice[item.mac].hosts).length }} {{ $i18n.t('hosts') }}</b-badge>
          <b-badge v-if="byDevice[item.mac]"
            class="ml-1">{{ Object.keys(byDevice[item.mac].protocols).length }} {{ $i18n.t('protocols') }}</b-badge>
        </b-col>
-->
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

import { computed, onMounted, ref } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const selectedSecurityEvents = computed(() => $store.state.$_network_threats.selectedSecurityEvents)

  const items = ref([])
  onMounted(() => {
    $store.dispatch('$_security_events/all').then(_items => {
      items.value = _items
        .sort((a, b) => a.desc.localeCompare(b.desc))
        .map(item => {
          switch(true) {
            case item.priority < 3:
              item._class = 'danger'
              break
            case item.priority < 6:
              item._class = 'warning'
              break
            default:
              item._class = 'success'
          }
          return item
        })
    })
  })

  const filter = ref('')
  const filteredItems = computed(() => {
    if (!filter.value) {
      return items.value
    }
    return items.value
      .filter(item => (item.desc.toLowerCase().indexOf(filter.value.toLowerCase()) > -1 || item.id.indexOf(filter.value) > -1))
  })
  const onSelectItem = item => {
    $store.dispatch('$_network_threats/toggleSecurityEvent', item.id)
  }
  const onSelectAll = () => {
    $store.dispatch('$_network_threats/selectSecurityEvents', filteredItems.value.map(item => item.id))
  }
  const onSelectNone = () => {
    $store.dispatch('$_network_threats/deselectSecurityEvents', filteredItems.value.map(item => item.id))
  }
  const onSelectInverse = () => {
    $store.dispatch('$_network_threats/invertSecurityEvents', filteredItems.value.map(item => item.id))
  }

  return {
    filter,
    filteredItems,

    selectedSecurityEvents,

    onSelectItem,
    onSelectAll,
    onSelectNone,
    onSelectInverse,
  }
}

// @vue/component
export default {
  name: 'base-filter-security-events',
  inheritAttrs: false,
  components,
  directives,
  setup
}
</script>