<template>
  <base-search :use-search="useNodesSearch">
    <template v-slot:header>
      <p class="py-0 col-form-label text-left text-nowrap" v-text="'Condition'"></p>
    </template>
    <template v-slot:footer>
      <b-container class="mt-3 p-0">
        <p class="d-inline py-0 col-form-label text-left text-nowrap" v-text="'Device Class'" />
        <b-badge v-if="selectedDeviceClasses.length" pill variant="primary" class="ml-1">{{ selectedDeviceClasses.length }}</b-badge>
      </b-container>
      <b-row align-v="center">
        <b-col cols="6" v-for="deviceClass in decoratedDeviceClasses" :key="deviceClass.id"
          @click="toggleDeviceClass(deviceClass)"
          class="bg-hover-success cursor-pointer py-1"
          :class="(selectedDeviceClasses.indexOf(deviceClass.id) > -1) ? 'text-success' : 'text-muted'"
        >
          <icon :name="`fingerbank-${deviceClass.id}`" class="mr-1 mb-1" />
          {{ deviceClass.name }}
        </b-col>
      </b-row>
    </template>
  </base-search>
</template>

<script>
import {
  BaseSearch,
} from '@/components/new/'

const components = {
  BaseSearch
}

import { computed, toRefs, watch } from '@vue/composition-api'
import usePreference from '@/composables/usePreference'
import { useNodesSearch } from '../_composables/useCollection'
import icons from '@/assets/icons/fingerbank'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const search = useNodesSearch()
  const {
    reSearch
  } = search
  const {
    items
  } = toRefs(search)

  const deviceClasses = computed(() => $store.state.$_fingerbank.classes
    .sort((a, b) => a.name.localeCompare(b.name)))

  const decoratedDeviceClasses = computed(() => deviceClasses.value.map(item => {
      const { id, name } = item
      return { id, name, icon: icons[id] }
  }))

  const selectedDeviceClasses = usePreference('vizsec::filters', 'categories', [])
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

  watch(selectedDeviceClasses, () => {
    search.requestInterceptor = request => {
      // override Node defaults
      if (selectedDeviceClasses.value.length > 0) {
        // request.query can be null
        request.query = {
          ...(request.query || { op: 'and', values: [] })
        }
        // push criteria
        request.query.values.push({
          op: 'or',
          values: selectedDeviceClasses.value.map(id => ({
            field: 'device_class', op: 'equals', value: assocClassesById.value[id]
          }))
        })
      }
      return request
    }
    reSearch()
  }, { immediate: true })

  const selectedDevices = computed(() => $store.state.$_fingerbank_communication.selectedDevices.value)
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

  watch([selectedDevices, uniqueItems], () => {
    if (selectedDevices.value.length === 0 && uniqueItems.value.length > 0) {
      $store.dispatch('$_fingerbank_communication/getDebounced', { nodes: uniqueItems.value.map(item => item.mac) })
    }
    else {
      $store.dispatch('$_fingerbank_communication/getDebounced', { nodes: selectedDevices.value })
    }
  }, { deep: true, immediate: true })

  return {
    useNodesSearch,

    ...toRefs(search),
    decoratedDeviceClasses,
    selectedDeviceClasses,
    toggleDeviceClass,
  }
}

// @vue/component
export default {
  name: 'the-search',
  components,
  setup
}
</script>