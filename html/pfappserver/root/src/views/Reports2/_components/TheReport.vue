<template>
  <pre>{{ {report, meta, id} }}</pre>
</template>

<script>
const components = {}

const props = {
  id: {
    type: String
  }
}

import { ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { useStore } from '../_store'
const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const {
    getItem,
    getItemOptions
  } = useStore($store)

  const report = ref(null)
  const meta = ref(null)

  watch(id, () => {
    report.value = null
    meta.value = null
    getItem({ id: id.value }).then(item => {
      report.value = item
    })
    getItemOptions({ id: id.value }).then(options => {
      const { report_meta } = options
      meta.value = report_meta
    })
  }, { immediate: true })

  return {
    report,
    meta
  }
}

// @vue/component
export default {
  name: 'TheReport',
  components,
  props,
  setup
}
</script>