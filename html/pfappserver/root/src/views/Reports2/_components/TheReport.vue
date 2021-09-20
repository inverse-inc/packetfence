<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-html="id" />
      <p v-if="description"
        v-html="description" class="mt-3 mb-0" />
    </b-card-header>
    <div class="card-body">
      <the-search v-if="isLoaded"
        :meta="meta"
        :report="report"
      />
      <base-container-loading v-else
        :title="$i18n.t('Building Report')"
        :text="$i18n.t('Hold on a moment while we render it...')"
        spin
      />
    </div>
<pre>{{ {report, meta } }}</pre>
  </b-card>
</template>

<script>
import {
  BaseContainerLoading
} from '@/components/new/'
import TheSearch from './TheSearch'
const components = {
  BaseContainerLoading,
  TheSearch
}

const props = {
  id: {
    type: String
  }
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
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

  const report = ref({})
  const meta = ref({})
  const isLoaded = ref(false)

  watch(id, () => {
    report.value = {}
    meta.value = {}
    isLoaded.value = false
    let promises = []
    promises[promises.length] = getItem({ id: id.value }).then(item => {
      report.value = item
    })
    promises[promises.length] = getItemOptions({ id: id.value }).then(options => {
      const { report_meta = {} } = options
      meta.value = report_meta
    })
    Promise.all(promises).finally(() => {
      isLoaded.value = true
    })
  }, { immediate: true })

  const description = computed(() => {
    const { description } = report.value
    return description
  })

  const hasCursor = computed(() => {
    const { has_cursor } = meta.value
    return has_cursor
  })

  const hasDateRange = computed(() => {
    const { has_date_range } = meta.value
    return has_date_range
  })

  return {
    isLoaded,
    report,
    meta,
    description,
    hasCursor,
    hasDateRange
  }
}

// @vue/component
export default {
  name: 'the-report',
  components,
  props,
  setup
}
</script>