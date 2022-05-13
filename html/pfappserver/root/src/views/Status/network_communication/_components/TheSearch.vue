<template>
  <base-search :use-search="useNodesSearch">
    <template v-slot:header>
      <p class="py-0 col-form-label text-left text-nowrap" v-text="'Condition'"></p>
    </template>
    <template v-slot:footer>
      <p class="py-0 col-form-label text-left text-nowrap mt-3" v-text="'Device Class'"></p>
      <b-row>
        <b-col cols="12" v-for="deviceClass in deviceClassList" :key="deviceClass.value"
          @click="toggleDeviceClass(deviceClass)"
        >
          <icon v-if="selectedDeviceClasses.indexOf(deviceClass.text) > -1"
            name="check-square" class="bg-white text-success mr-1" scale="1.125" />
          <icon v-else
            name="square" class="border border-1 border-gray bg-white text-light mr-1" scale="1.125" />
          {{ deviceClass.text }}
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

import { onMounted, ref, toRefs, watch } from '@vue/composition-api'
import { useNodesSearch } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const search = useNodesSearch()
  const {
    reSearch
  } = search

  const deviceClassList = ref([])
  onMounted(() => {
    $store.dispatch('$_fingerbank/devices').then(items => {
      deviceClassList.value = items
        .map(({ id: value, name: text}) => ({ text, value }))
        .sort((a, b) => a.text.localeCompare(b.text))
    })
  })

  const selectedDeviceClasses = ref([])
  const toggleDeviceClass = deviceClass => {
    const { text } = deviceClass
    if (selectedDeviceClasses.value.indexOf(text) === -1) {
      selectedDeviceClasses.value = [
        ...selectedDeviceClasses.value.filter(selected => selected !== text),
        text
      ]
    }
    else {
      selectedDeviceClasses.value = selectedDeviceClasses.value.filter(selected => selected !== text)
    }
  }

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
          values: selectedDeviceClasses.value.map(deviceClass => ({
            field: 'device_class', op: 'equals', value: deviceClass
          }))
        })
      }
      return request
    }
    reSearch()
  }, { immediate: true })

  return {
    useNodesSearch,

    ...toRefs(search),
    deviceClassList,
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