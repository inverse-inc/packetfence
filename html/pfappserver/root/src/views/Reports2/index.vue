<template>
  <b-row>
    <pf-sidebar v-model="sections" />
    <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
      <!-- avoid component re-use, since useSearch is not reactive -->
      <router-view :key="$route.fullPath" />
    </b-col>
  </b-row>
</template>

<script>
import pfSidebar from '@/components/pfSidebar'
const components = {
  pfSidebar
}

import { computed, onMounted, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { delimiter } from './config'
const setup = (props, context) => {

const { root: { $store } = {} } = context

  const reports = ref([])
  onMounted(() => $store.dispatch('$_reports/all')
    .then(_reports => {
      reports.value = _reports
    })
  )

  const _struct = associated => {
    return Object.keys(associated).map(key => {
      const { depth = 0, children = {}, id } = associated[key]
      switch (depth) {
        case 2:
          return {
            name: i18n.t(key), // i18n defer
            collapsable: true,
            items: _struct(children) // recursive
          }
          // break
        case 1:
          return {
            name: i18n.t(key), // i18n defer
            items: _struct(children) // recursive
          }
          // break
        case 0:
          return {
            name: i18n.t(key), // i18n defer
            path: `/reports2/${id}`,
//            saveSearchNamespace: `reports::${id}`
          }
          // break
      }
    })
  }

  const sections = computed(() => {
    // just the id's ma'am
    const flat = reports.value.map(report => report.id)
    // sort by locale
    const sorted = flat.sort((a, b) => a.localeCompare(b))
    // flatten ids into associated tree using delimiter
    const associated = sorted.reduce((associated, id) => {
      const namespace = id.split(delimiter)
      let pointer = associated
      for (let n = 0; n < namespace.length; n++) {
        if (!(namespace[n] in pointer))
          pointer[namespace[n]] = {
            depth: namespace.length - n - 1,
            children: {},
            id
          }
        pointer = pointer[namespace[n]].children
      }
      return associated
    }, {})
    // return structured items
    return _struct(associated)
  })

  return {
    sections
  }
}

// @vue/component
export default {
  name: 'Reports',
  components,
  setup
}
</script>
