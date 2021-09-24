<template>
  <b-card no-body id="card">
    <b-card-header>
      <h4 class="mb-0" v-html="id" />
      <p v-if="description"
        v-html="description" class="mt-3 mb-0" />
    </b-card-header>
    <div class="card-body">
      <template v-if="isLoaded">
        <the-search v-if="hasQuery"
          :meta="meta"
          :report="report"
        >
          <base-input-date-range v-if="hasDateRange"
            v-model="dateRange"
            :disabled="isLoading" />
        </the-search>
        <b-tabs v-if="charts.length"
          card lazy>
          <b-tab v-for="chart in charts" :key="chart">
            <template #title>
              <icon :name="chartIcon(chart)" scale="1.25" />
            </template>
            <component
              :is="chartComponent(chart)"
              v-bind="chartProps(chart)"
            />
          </b-tab>
        </b-tabs>
        <the-table
          :meta="meta"
          :report="report"
        >
          <base-input-date-range v-if="hasDateRange"
            v-model="dateRange"
            :disabled="isLoading" />
        </the-table>
      </template>
      <base-container-loading v-else
        :title="$i18n.t('Building Report')"
        :text="$i18n.t('Hold on a moment while we render it...')"
        spin
      />
    </div>
  </b-card>
</template>

<script>
import {
  BaseContainerLoading
} from '@/components/new/'
import BaseInputDateRange from './BaseInputDateRange'
import TheSearch from './TheSearch'
import TheTable from './TheTable'
const components = {
  BaseContainerLoading,
  BaseInputDateRange,
  TheSearch,
  TheTable
}

import BaseChartBar from './BaseChartBar'
import BaseChartPie from './BaseChartPie'

const props = {
  id: {
    type: String
  }
}

import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import { useSearchFactory } from '../_search'
import { useStore } from '../_store'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const {
    getItem,
    getItemOptions,
    isLoading
  } = useStore($store)

  const report = ref({})
  const meta = ref({})
  const isLoaded = ref(false)

  const dateRange = ref({})
  watch(dateRange, () => {
    const { start_date, end_date } = dateRange.value
    // append dates to meta, consumed by search::requestInterceptor
    meta.value = { ...meta.value, start_date, end_date }
    // wait for meta prop to propagate
    nextTick(() => {
      // trigger reSearch
      const useSearch = useSearchFactory(report, meta)
      const search = useSearch()
      search.reSearch()
    })
  })

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
      const { start_date, end_date } = dateRange.value
      // append dates to meta, consumed by search::requestInterceptor
      meta.value = { ...report_meta, start_date, end_date }
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

  const hasQuery = computed(() => {
    const { query_fields = [] } = meta.value
    return !!query_fields.length
  })


  const charts = computed(() => {
    const { charts = [] } = meta.value
    return charts
  })
  const chartComponent = chart => {
    const [ type ] = chart.split('|')
    switch (type) {
      case 'bar':
        return BaseChartBar
      case 'pie':
        return BaseChartPie
    }
  }
  const chartProps = chart => {
    const { 1: options = '' } = chart.split('|')
    const [ field, count ] = options.split(':')
    return {
      field,
      count,
      meta,
      report
    }
  }
  const chartIcon = chart => {
    const [ type ] = chart.split('|')
    switch (type) {
      case 'bar':
        return 'chart-bar'
      case 'pie':
        return 'chart-pie'
    }
  }

  return {
    isLoading,
    isLoaded,
    report,
    meta,
    description,
    hasCursor,
    hasDateRange,
    hasQuery,

    dateRange,

    charts,
    chartComponent,
    chartProps,
    chartIcon
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  props,
  setup
}
</script>

