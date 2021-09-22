<template>
  <b-row>
    <pf-sidebar v-model="sections" />
    <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
      <router-view />
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

  const _depth = (item, depth = 0) => {
    let d = depth
      const { children = {} } = item
      Object.keys(children).forEach(key => {
          depth = Math.max(depth, _depth(children[key], d + 1))
      })
    return depth
  }

  const _struct = (associated, parents = 0) => {
    return Object.keys(associated).map(key => {
      const { children = {}, id, charts = '' } = associated[key]
      const icon = (charts.split(',').includes('pie'))
        ? 'chart-pie'
        : null
      const depth = _depth(associated[key])
      switch (true) {
        case depth === 2 && parents === 0:
        case depth === 1 && parents === 0:
          return {
            name: i18n.t(key), // i18n defer
            collapsable: true,
            items: _struct(children, parents + 1) // recursive
          }
          // break
        case depth === 1 && parents === 1:
          return {
            name: i18n.t(key), // i18n defer
            items: _struct(children, parents + 1) // recursive
          }
          // break
        case depth === 0:
          return {
            name: i18n.t(key), // i18n defer
            path: `/reports2/${id}`,
            saveSearchNamespace: `reports::${id}`,
            icon
          }
          // break
      }
    })
  }

  const sections = computed(() => {
    // sort by id
    const sorted = reports.value.sort((a, b) => a.id.localeCompare(b.id))
    // flatten reports into associated tree using delimiter
    const associated = sorted.reduce((associated, report) => {
      const { id, charts } = report
      const namespace = id.split(delimiter)
      let pointer = associated
      for (let n = 0; n < namespace.length; n++) {
        if (!(namespace[n] in pointer))
          pointer[namespace[n]] = { children: {}, id, charts }
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
