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
      <b-row v-for="item in filteredItems" :key="item.id"
        @click="onSelectItem(item)"
        align-v="center"
        class="mx-1 mt-1 text-nowrap border border-1 cursor-pointer"
        :class="(value.indexOf(item.id) > -1) ? 'border-success' : ''"
      >
        <b-col cols="1" class="px-0 py-3 text-center">
          <template v-if="value.indexOf(item.id) > -1">
            <icon name="check-square" class="bg-white text-success" scale="1.125" />
          </template>
          <template v-else>
            <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
          </template>
        </b-col>
        <b-col cols="auto" class="px-0 py-3 mr-auto">
          <text-highlight :queries="[filter]">{{ item.desc }}</text-highlight>
        </b-col>
        <b-col cols="auto">
          <b-badge v-if="item._open"
            variant="danger" class="ml-1">{{ item._open }} {{ $i18n.t('open') }}</b-badge>
          <b-badge v-if="item._closed"
            variant="light" class="ml-1">{{ item._closed }} {{ $i18n.t('closed') }}</b-badge>
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
  value: {
    type: Array,
    default: () => ([])
  }
}

import { computed, onMounted, ref, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    value
  } = toRefs(props)

  const { emit, root: { $store } = {} } = context

  const perSecurityEventOpen = computed(() => $store.getters['$_network_threats/perSecurityEventOpen'])
  const perSecurityEventClosed = computed(() => $store.getters['$_network_threats/perSecurityEventClosed'])

  const items = ref([])
  onMounted(() => {
    $store.dispatch('$_security_events/all').then(_items => {
      items.value = _items
        .sort((a, b) => a.desc.localeCompare(b.desc))
    })
  })

  const decoratedItems = computed(() => items.value.map(item => {
    const { id } = item
    const _open = perSecurityEventOpen.value[id] || 0
    const _closed = perSecurityEventClosed.value[id] || 0
    return { ...item,
      _open, _closed }
  }))

  const filter = ref('')
  const filteredItems = computed(() => {
    if (!filter.value) {
      return decoratedItems.value
    }
    return decoratedItems.value
      .filter(item => (item.desc.toLowerCase().indexOf(filter.value.toLowerCase()) > -1 || item.id.indexOf(filter.value) > -1))
  })
  const onSelectItem = item => {
    const i = value.value.findIndex(selected => selected === item.id)
    if (i > -1) {
      emit('input', [ ...value.value.filter(selected => selected !== item.id) ])
    }
    else {
      emit('input', [ ...value.value, item.id ])
    }
  }
  const onSelectAll = () => {
    let input = [ ...value.value ]
    filteredItems.value.map(item => item.id).forEach(securityEvent => {
      if (input.indexOf(securityEvent) === -1) {
        input.push(securityEvent)
      }
    })
    emit('input', input)
  }
  const onSelectNone = () => {
    let input = [ ...value.value ]
    filteredItems.value.map(item => item.id).forEach(securityEvent => {
      if (input.indexOf(securityEvent) > -1) {
        input = input.filter(selected => selected !== securityEvent)
      }
    })
    emit('input', input)
  }
  const onSelectInverse = () => {
    let input = [ ...value.value ]
    filteredItems.value.map(item => item.id).forEach(securityEvent => {
      if (input.indexOf(securityEvent) === -1) {
        input.push(securityEvent)
      }
      else {
        input = input.filter(selected => selected !== securityEvent)
      }
    })
    emit('input', input)
  }

  return {
    filter,
    filteredItems,
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
  props,
  setup
}
</script>