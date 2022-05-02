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

      <b-row v-for="item in filteredItems" :key="item.device_class"
        @click="onSelectItem(item)"
        align-v="center"
        :class="{
          'filter-selected': value.indexOf(item.device_class) > -1
        }">
        <b-col cols="1" class="px-3 py-1 ml-3 text-center">
          <template v-if="value.indexOf(item.device_class) > -1">
            <icon name="check-square" class="bg-white text-success" scale="1.125" />
          </template>
          <template v-else>
            <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
          </template>
        </b-col>
        <b-col cols="auto mr-auto" class="px-3 py-1">
          <text-highlight :queries="[filter]">{{ item.device_class }}</text-highlight>
        </b-col>
        <b-col cols="auto mr-3">
          <b-badge class="ml-1">{{ uniqueDevices[item.device_class] }} {{ $i18n.t('devices') }}</b-badge>
          <b-badge class="ml-1">{{ uniqueProtocols[item.device_class] }} {{ $i18n.t('protocols') }}</b-badge>
          <b-badge class="ml-1">{{ uniqueHosts[item.device_class] }} {{ $i18n.t('hosts') }}</b-badge>
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

import { computed, nextTick, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    items,
    value
  } = toRefs(props)

  const { emit } = context

  const uniqueItems = computed(() => {
    return Object.values(items.value)
      .reduce((unique, item) => {
        if (unique.filter(u => u.device_class === item.device_class).length === 0) {
          return [ ...unique, item ]
        }
        return unique
      }, [])
      .sort((a, b) => a.device_class.localeCompare(b.device_class))
  })

  const filter = ref('')

  const filteredItems = computed(() => {
    if (!filter.value) {
      return uniqueItems.value
    }
    return uniqueItems.value
      .filter(item => (item.device_class.indexOf(filter.value) > -1))
  })


  const onSelectItem = item => {
    const isSelected = value.value.findIndex(device_class => device_class === item.device_class)
    if (isSelected > -1) { // remove
      emit('input', [ ...value.value.filter(device_class => device_class !== value.value[isSelected]) ])
    }
    else { // insert
      emit('input', [ ...value.value, item.device_class ])
    }
  }

  const onSelectAll = () => {
    let selected = value.value
    filteredItems.value.forEach((item) => {
      let i = selected.indexOf(item.device_class)
      if (i === -1) {
        selected = [ ...selected, item.device_class ]
      }
    })
    emit('input', selected)
  }

  const onSelectNone = () => {
    let selected = value.value
    filteredItems.value.forEach((item) => {
      let i = selected.indexOf(item.device_class)
      if (i > -1) {
        selected = selected.filter((_, j) => j !== i)
      }
    })
    emit('input', selected)
  }

  const onSelectInverse = () => {
    let selected = value.value
    filteredItems.value.forEach((item) => {
      let i = selected.indexOf(item.device_class)
      if (i > -1) {
        selected = selected.filter((_, j) => j !== i)
      }
      else {
        selected = [ ...selected, item.device_class ]
      }
    })
    emit('input', selected)
  }

  const uniqueDevices = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { device_class, mac } = item
      unique[device_class] = [ ...unique[device_class] || [], mac ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, device_class) => {
      return { ...unique, [device_class]: assoc[device_class].length }
    }, {})
  })

  const uniqueProtocols = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { device_class, proto, port } = item
      const protocol = `${proto}/${port}`
      unique[device_class] = [ ...unique[device_class] || [], protocol ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, device_class) => {
      return { ...unique, [device_class]: assoc[device_class].length }
    }, {})
  })

  const uniqueHosts = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { device_class, host } = item
      unique[device_class] = [ ...unique[device_class] || [], host ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, device_class) => {
      return { ...unique, [device_class]: assoc[device_class].length }
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

    uniqueDevices,
    uniqueProtocols,
    uniqueHosts,
  }
}

// @vue/component
export default {
  name: 'base-filter-categories',
  components,
  directives,
  props,
  setup
}
</script>