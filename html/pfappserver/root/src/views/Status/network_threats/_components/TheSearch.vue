<template>
  <base-search :use-search="useSearch" hide-cursor>
    <template v-slot:header>
      <p class="py-0 col-form-label text-left text-nowrap" v-text="'Condition'"></p>
    </template>
    <template v-slot:footer>
      <b-row class="mt-3 p-0">
        <b-col cols="auto" class="mr-auto">
          <p class="d-inline py-0 col-form-label text-left text-nowrap" v-text="'Device Class'" />
          <b-badge v-if="selectedDeviceClasses.length" pill variant="primary" class="ml-1">{{ selectedDeviceClasses.length }}</b-badge>
          <base-icon-preference :id="preference"
            class="ml-1" />
        </b-col>
        <b-col cols="auto" class="text-right">
          <b-btn variant="link" size="sm" class="text-secondary"
            @click="onSelectAll">{{ $i18n.t('All') }}</b-btn>
          <b-btn variant="link" size="sm" class="text-secondary"
            @click="onSelectNone">{{ $i18n.t('None') }}</b-btn>
          <b-btn variant="link" size="sm" class="text-secondary"
            @click="onSelectInverse">{{ $i18n.t('Invert') }}</b-btn>
        </b-col>
      </b-row>
      <b-row align-v="center">
        <b-col cols="6" v-for="deviceClass in decoratedDeviceClasses" :key="deviceClass.id"
          @click="toggleDeviceClass(deviceClass)"
          class="cursor-pointer p-1">
          <div class="border border-1 p-1"
            :class="(selectedDeviceClasses.indexOf(deviceClass.id) > -1)
              ? 'bg-hover-success border-success'
              : 'bg-hover-secondary'
            ">
            <b-row align-v="center">
              <b-col cols="auto">
                <icon :name="`fingerbank-${deviceClass.id}`" class="mr-1 mb-1"
                  :class="(selectedDeviceClasses.indexOf(deviceClass.id) > -1) ? 'text-success' : 'text-muted'" />
                {{ deviceClass.name }}
              </b-col>
              <b-col v-if="deviceClass._count"
                cols="auto" class="ml-auto">
                <b-badge>{{ deviceClass._count }} {{ $i18n.t('nodes') }}</b-badge>
              </b-col>
            </b-row>
          </div>
        </b-col>
      </b-row>
    </template>
  </base-search>
</template>

<script>
import {
  BaseIconPreference,
  BaseSearch,
} from '@/components/new/'
const components = {
  BaseIconPreference,
  BaseSearch
}

const props = {
  selectedSecurityEvents: {
    type: Array
  }
}

import { computed, toRefs, watch } from '@vue/composition-api'
import usePreference from '@/composables/usePreference'
import { useSearch } from '../_search'
import icons from '@/assets/icons/fingerbank'

const preference = 'vizsec::filters'

const setup = (props, context) => {

  const {
    selectedSecurityEvents
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const search = useSearch()
  const {
    reSearch,
    setPage,
  } = search

  const deviceClasses = computed(() => $store.state.$_fingerbank.classes
    .sort((a, b) => a.name.localeCompare(b.name)))

  const perDeviceClassLowerCase = computed(() => $store.getters['$_nodes/perDeviceClassLowerCase'])

  const decoratedDeviceClasses = computed(() => deviceClasses.value.map(item => {
    const { id, name } = item
    const _count = (name.toLowerCase() in perDeviceClassLowerCase.value) // case insensitive
      ? perDeviceClassLowerCase.value[name.toLowerCase()]
      : 0
    return { id, name, icon: icons[id],
      _count }
  }))

  const selectedDeviceClasses = usePreference(preference, 'categories', [])
  const toggleDeviceClass = deviceClass => {
    const { id } = deviceClass
    if (selectedDeviceClasses.value.indexOf(id) === -1) {
      selectedDeviceClasses.value = [
        ...selectedDeviceClasses.value.filter(selected => selected !== id),
        id
      ]
    }
    else {
      selectedDeviceClasses.value = selectedDeviceClasses.value.filter(selected => selected !== id)
    }
  }

  const assocClassesById = computed(() => $store.getters['$_fingerbank/assocClassesById'])

  watch([selectedDeviceClasses, selectedSecurityEvents], () => {
    search.requestInterceptor = request => {
      if (selectedDeviceClasses.value.length && Object.keys(assocClassesById.value).length) {
        // request.query can be null
        request.query = {
          ...(request.query || { op: 'and', values: [] })
        }
        // push criteria
        request.query.values.push({ op: 'or', values: selectedDeviceClasses.value.map(value => { return { field: 'node.device_class', op: 'equals', value: assocClassesById.value[value] || null }}) })
      }
      if (selectedSecurityEvents.value.length) {
        // request.query can be null
        request.query = {
          ...(request.query || { op: 'and', values: [] })
        }
        // push criteria
        request.query.values.push({ op: 'or', values: selectedSecurityEvents.value.map(value => { return { field: 'security_event_id', op: 'equals', value }}) })
      }
      return request
    }
    setPage(1)
    reSearch()
  }, { deep: true, immediate: true })

  const onSelectAll = () => {
    selectedDeviceClasses.value = deviceClasses.value.map(item => item.id)
  }
  const onSelectNone = () => {
    selectedDeviceClasses.value = []
  }
  const onSelectInverse = () => {
    let input = [ ...selectedDeviceClasses.value ]
    deviceClasses.value.map(item => item.id).forEach(category => {
      if (input.indexOf(category) === -1) {
        input.push(category)
      }
      else {
        input = input.filter(selected => selected !== category)
      }
    })
    selectedDeviceClasses.value = input
  }

  return {
    useSearch,

    ...toRefs(search),
    decoratedDeviceClasses,
    selectedDeviceClasses,
    toggleDeviceClass,
    onSelectAll,
    onSelectInverse,
    onSelectNone,
    preference,
  }
}

// @vue/component
export default {
  name: 'the-search',
  components,
  props,
  setup
}
</script>