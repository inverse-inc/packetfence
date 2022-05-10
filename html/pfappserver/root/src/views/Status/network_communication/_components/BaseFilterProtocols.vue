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
    <div class="card-body p-0 filtered-items">

      <b-btn variant="link" size="sm" class="text-secondary"
        @click="onSelectAll">{{ $i18n.t('All') }}</b-btn>
      <b-btn variant="link" size="sm" class="text-secondary"
        @click="onSelectNone">{{ $i18n.t('None') }}</b-btn>
      <b-btn variant="link" size="sm" class="text-secondary"
        @click="onSelectInverse">{{ $i18n.t('Inverse') }}</b-btn>

      <b-row v-for="item in filteredItems" :key="`${item.proto}/${item.port}`"
        @click="onSelectItem(item)"
        align-v="center"
        :class="{
          'filter-selected': value.indexOf(`${item.proto}/${item.port}`) > -1
        }">
        <b-col cols="1" class="px-3 py-1 ml-3 text-center">
          <template v-if="value.indexOf(`${item.proto}/${item.port}`) > -1">
            <icon name="check-square" class="bg-white text-success" scale="1.125" />
          </template>
          <template v-else>
            <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
          </template>
        </b-col>
        <b-col cols="auto mr-auto" class="px-3 py-1 mr-3">
          <text-highlight :queries="[filter]">{{ item.proto }}/{{ item.port }}</text-highlight>
        </b-col>
        <b-col cols="auto mr-3">
          <b-badge class="ml-1">{{ uniqueCategories[`${item.proto}/${item.port}`] }} {{ $i18n.t('categories') }}</b-badge>
          <b-badge class="ml-1">{{ uniqueDevices[`${item.proto}/${item.port}`] }} {{ $i18n.t('devices') }}</b-badge>
          <b-badge class="ml-1">{{ uniqueHosts[`${item.proto}/${item.port}`] }} {{ $i18n.t('hosts') }}</b-badge>
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
        if (unique.filter(u => u.proto === item.proto && u.port === item.port).length === 0) {
          return [ ...unique, item ]
        }
        return unique
      }, [])
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
      return uniqueItems.value
    }
    return uniqueItems.value
      .filter(item => (item.proto.toLowerCase().indexOf(filter.value.toLowerCase()) > -1 || `${item.port}`.indexOf(filter.value) > -1))
  })


  const onSelectItem = item => {
    const protocol = `${item.proto}/${item.port}`
console.log('onSelected', JSON.stringify({item}, protocol, null, 2))
    const isSelected = value.value.findIndex(item => item === protocol)
    if (isSelected > -1) { // remove
      emit('input', [ ...value.value.filter(item => item !== value.value[isSelected]) ])
    }
    else { // insert
      emit('input', [ ...value.value, protocol ])
    }
  }

  const onSelectAll = () => {
    let selected = value.value
    filteredItems.value.forEach((item) => {
      const protocol = `${item.proto}/${item.port}`
      let i = selected.indexOf(protocol)
      if (i === -1) {
        selected = [ ...selected, protocol ]
      }
    })
    emit('input', selected)
  }

  const onSelectNone = () => {
    let selected = value.value
    filteredItems.value.forEach((item) => {
      const protocol = `${item.proto}/${item.port}`
      let i = selected.indexOf(protocol)
      if (i > -1) {
        selected = selected.filter((_, j) => j !== i)
      }
    })
    emit('input', selected)
  }

  const onSelectInverse = () => {
    let selected = value.value
    filteredItems.value.forEach((item) => {
      const protocol = `${item.proto}/${item.port}`
      let i = selected.indexOf(protocol)
      if (i > -1) {
        selected = selected.filter((_, j) => j !== i)
      }
      else {
        selected = [ ...selected, protocol ]
      }
    })
    emit('input', selected)
  }

  const uniqueCategories = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { proto, port, device_class } = item
      const protocol = `${proto}/${port}`
      unique[protocol] = [ ...unique[protocol] || [], device_class ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, protocol) => {
      return { ...unique, [protocol]: assoc[protocol].length }
    }, {})
  })

  const uniqueDevices = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { proto, port, mac } = item
      const protocol = `${proto}/${port}`
      unique[protocol] = [ ...unique[protocol] || [], mac ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, protocol) => {
      return { ...unique, [protocol]: assoc[protocol].length }
    }, {})
  })

  const uniqueHosts = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { proto, port, host } = item
      const protocol = `${proto}/${port}`
      unique[protocol] = [ ...unique[protocol] || [], host ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, protocol) => {
      return { ...unique, [protocol]: assoc[protocol].length }
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
    uniqueDevices,
    uniqueHosts,
  }
}

// @vue/component
export default {
  name: 'base-filter-protocols',
  components,
  directives,
  props,
  setup
}
</script>