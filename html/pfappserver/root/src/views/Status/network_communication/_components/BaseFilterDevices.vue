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

      <b-row v-for="item in filteredItems" :key="item.mac"
        @click="onSelectItem(item)"
        align-v="center"
        :class="{
          'filter-selected': value.indexOf(item.mac) > -1
        }">
        <b-col cols="1" class="px-3 py-1 ml-3 text-center">
          <template v-if="value.indexOf(item.mac) > -1">
            <icon name="check-square" class="bg-white text-success" scale="1.125" />
          </template>
          <template v-else>
            <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
          </template>
        </b-col>
        <b-col cols="auto mr-auto" class="px-3 py-1 mr-3">
          <text-highlight :queries="[filter]">{{ item.mac }}</text-highlight>
        </b-col>
        <b-col cols="auto mr-3">
          <b-badge class="ml-1">{{ uniqueCategories[item.mac] }} {{ $i18n.t('categories') }}</b-badge>
          <b-badge class="ml-1">{{ uniqueProtocols[item.mac] }} {{ $i18n.t('protocols') }}</b-badge>
          <b-badge class="ml-1">{{ uniqueHosts[item.mac] }} {{ $i18n.t('hosts') }}</b-badge>
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

const props = {
  items: {
    type: Array
  },
  value: {
    type: Array
  }
}

import { computed, ref, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    items,
    value
  } = toRefs(props)

  const { emit } = context

  const uniqueItems = computed(() => {
    return Object.values(items.value)
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
    const isSelected = value.value.findIndex(mac => mac === item.mac)
    if (isSelected > -1) { // remove
      emit('input', [ ...value.value.filter(mac => mac !== value.value[isSelected]) ])
    }
    else { // insert
      emit('input', [ ...value.value, item.mac ])
    }
  }

  const onSelectAll = () => {
    let selected = value.value
    filteredItems.value.forEach((item) => {
      let i = selected.indexOf(item.mac)
      if (i === -1) {
        selected = [ ...selected, item.mac ]
      }
    })
    emit('input', selected)
  }

  const onSelectNone = () => {
    let selected = value.value
    filteredItems.value.forEach((item) => {
      let i = selected.indexOf(item.mac)
      if (i > -1) {
        selected = selected.filter((_, j) => j !== i)
      }
    })
    emit('input', selected)
  }

  const onSelectInverse = () => {
    let selected = value.value
    filteredItems.value.forEach((item) => {
      let i = selected.indexOf(item.mac)
      if (i > -1) {
        selected = selected.filter((_, j) => j !== i)
      }
      else {
        selected = [ ...selected, item.mac ]
      }
    })
    emit('input', selected)
  }

  const uniqueCategories = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { mac, device_class } = item
      unique[mac] = [ ...unique[mac] || [], device_class ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, mac) => {
      return { ...unique, [mac]: assoc[mac].length }
    }, {})
  })

  const uniqueProtocols = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { mac, proto, port } = item
      const protocol = `${proto}/${port}`
      unique[mac] = [ ...unique[mac] || [], protocol ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, mac) => {
      return { ...unique, [mac]: assoc[mac].length }
    }, {})
  })

  const uniqueHosts = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { mac, host } = item
      unique[mac] = [ ...unique[mac] || [], host ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, mac) => {
      return { ...unique, [mac]: assoc[mac].length }
    }, {})
  })

  return {
    filter,
    filteredItems,
    uniqueItems,
    onSelectItem,
    onSelectAll,
    onSelectNone,
    onSelectInverse,

    uniqueCategories,
    uniqueProtocols,
    uniqueHosts,
  }
}

// @vue/component
export default {
  name: 'base-filter-devices',
  components,
  directives,
  props,
  setup
}
</script>