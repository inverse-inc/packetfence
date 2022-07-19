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
        :class="(value.indexOf(+item.id) > -1)
          ? 'bg-hover-success border-success'
          : 'bg-hover-secondary'
        ">
        <b-col cols="auto" class="text-center">
          <icon :name="`fingerbank-${item.id}`" scale="1.5"
            :class="(value.indexOf(+item.id) > -1) ? 'text-success' : 'text-secondary'"
            />
        </b-col>
        <b-col cols="auto" class="p-3 mr-auto">
          <text-highlight :queries="[filter]">{{ item.name }}</text-highlight>
        </b-col>
        <b-col cols="auto">
          <b-badge v-if="item._count"
            class="ml-1">{{ item._count }} {{ $i18n.t('nodes') }}</b-badge>
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

import { computed, ref, toRefs } from '@vue/composition-api'
import icons from '@/assets/icons/fingerbank'

const setup = (props, context) => {

  const {
    value
  } = toRefs(props)

  const { emit, root: { $store } = {} } = context

  const perDeviceClassLowerCase = computed(() => $store.getters['$_nodes/perDeviceClassLowerCase'])
  const perDeviceClassOpen = computed(() => $store.getters['$_network_threats/perDeviceClassOpen'])
  const perDeviceClassClosed = computed(() => $store.getters['$_network_threats/perDeviceClassClosed'])

  const items = computed(() => $store.state.$_fingerbank.classes
    .sort((a, b) => a.name.localeCompare(b.name)))

  const decoratedItems = computed(() => items.value.map(item => {
    const { id, name } = item
    const _count = (name.toLowerCase() in perDeviceClassLowerCase.value) // case insensitive
      ? perDeviceClassLowerCase.value[name.toLowerCase()]
      : 0
    const _open = perDeviceClassOpen.value[name] || 0
    const _closed = perDeviceClassClosed.value[name] || 0
    return { id, name, icon: icons[id],
      _count, _open, _closed }
  }))

  const filter = ref('')
  const filteredItems = computed(() => {
    if (!filter.value) {
      return decoratedItems.value
    }
    return decoratedItems.value
      .filter(item => item.name.toLowerCase().indexOf(filter.value.toLowerCase()) > -1)
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
    filteredItems.value.map(item => item.id).forEach(category => {
      if (input.indexOf(category) === -1) {
        input.push(category)
      }
    })
    emit('input', input)
  }
  const onSelectNone = () => {
    let input = [ ...value.value ]
    filteredItems.value.map(item => item.id).forEach(category => {
      if (input.indexOf(category) > -1) {
        input = input.filter(selected => selected !== category)
      }
    })
    emit('input', input)
  }
  const onSelectInverse = () => {
    let input = [ ...value.value ]
    filteredItems.value.map(item => item.id).forEach(category => {
      if (input.indexOf(category) === -1) {
        input.push(category)
      }
      else {
        input = input.filter(selected => selected !== category)
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
  name: 'base-filter-categories',
  inheritAttrs: false,
  components,
  directives,
  props,
  setup
}
</script>
