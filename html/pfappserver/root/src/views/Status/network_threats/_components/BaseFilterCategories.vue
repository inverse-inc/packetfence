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
        :class="{
          'border-success': selectedCategories.indexOf(item.id) > -1
        }">
        <b-col cols="auto" class="text-center">
          <icon :name="`fingerbank-${item.id}`" scale="1.5"
            :class="(selectedCategories.indexOf(item.id) > -1) ? 'text-success' : 'text-secondary'"
            />
        </b-col>
        <b-col cols="auto" class="p-3">
          <text-highlight :queries="[filter]">{{ item.name }}</text-highlight>
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

import { computed, onMounted, ref } from '@vue/composition-api'
import { devices } from '@/views/Configuration/fingerbank/devices/config'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const selectedCategories = computed(() => $store.state.$_network_threats.selectedCategories)

  const items = ref([])
  onMounted(() => {
    $store.dispatch('$_fingerbank/devices').then(_items => {
      items.value = _items
        .map(item => {
          const { id, name } = item
          return { id, name, icon: devices[id].icon }
        })
        .sort((a, b) => a.name.localeCompare(b.name))
    })
  })

  const filter = ref('')
  const filteredItems = computed(() => {
    if (!filter.value) {
      return items.value
    }
    return items.value
      .filter(item => item.name.toLowerCase().indexOf(filter.value.toLowerCase()) > -1)
  })
  const onSelectItem = item => {
    $store.dispatch('$_network_threats/toggleCategory', item.id)
  }
  const onSelectAll = () => {
    $store.dispatch('$_network_threats/selectCategories', filteredItems.value.map(item => item.id))
  }
  const onSelectNone = () => {
    $store.dispatch('$_network_threats/deselectCategories', filteredItems.value.map(item => item.id))
  }
  const onSelectInverse = () => {
    $store.dispatch('$_network_threats/invertCategories', filteredItems.value.map(item => item.id))
  }

  return {
    filter,
    filteredItems,

    selectedCategories,

    onSelectItem,
    onSelectAll,
    onSelectNone,
    onSelectInverse,
  }
}

// @vue/component
export default {
  name: 'base-filter-categories',
  inheritAttrs: false,
  components,
  directives,
  setup
}
</script>
