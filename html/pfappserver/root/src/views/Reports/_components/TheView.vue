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
        >
          <base-input-date-range v-if="hasDateRange"
            v-model="dateRange"
            :disabled="isLoading" />
        </the-search>
        <b-tabs v-if="charts.length"
          card lazy>
          <b-tab v-for="chart in charts" :key="chart">
            <template #title>
              {{ chartName(chart) }} <icon :name="chartIcon(chart)" scale="1.25" class="mx-1" />
            </template>
            <component
              :is="chartComponent(chart)"
              v-bind="chartProps(chart)"
            />
          </b-tab>
        </b-tabs>
        <the-table
          :meta="meta"
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
import BaseChartParallel from './BaseChartParallel'
import BaseChartScatter from './BaseChartScatter'

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
      const useSearch = useSearchFactory(meta)
      const search = useSearch()
      search.reSearch()
    })
  })

  watch(id, () => {
    meta.value = {}
    isLoaded.value = false
    getItemOptions({ id: id.value })
      .then(options => {
        const { report_meta = {} } = options
        const { start_date, end_date } = dateRange.value
        // append dates to meta, consumed by search::requestInterceptor
        meta.value = { ...report_meta, start_date, end_date }
      })
      .finally(() => {
        isLoaded.value = true
      })
  }, { immediate: true })

  const description = computed(() => {
    const { description } = meta.value
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
    const [ typeName ] = chart.split('|')
    const [ type ] = typeName.split('@')
    switch (true) {
      case /^bar/.test(type):
        return BaseChartBar
      case /^pie/.test(type):
        return BaseChartPie
      case /^parallel/.test(type):
        return BaseChartParallel
      case /^scatter/.test(type):
        return BaseChartScatter
    }
  }
  const chartName = chart => {
    const [ typeName ] = chart.split('|')
    const { length, [1]: name } = typeName.split('@')
    if (length)
      return name
  }
  const chartProps = chart => {
    const { 1: fields = '' } = chart.split('|')
    const title = chartName(chart) || description.value
    return {
      fields,
      meta,
      title
    }
  }
  const chartIcon = chart => {
    const [ type ] = chart.split('|')
    switch (true) {
      case /^bar/.test(type):
        return 'chart-bar'
      case /^pie/.test(type):
        return 'chart-pie'
      case /^parallel/.test(type):
        return 'chart-line'
      case /^scatter/.test(type):
        return 'chart-line'
    }
  }

  return {
    isLoading,
    isLoaded,
    meta,
    description,
    hasCursor,
    hasDateRange,
    hasQuery,

    dateRange,

    charts,
    chartComponent,
    chartName,
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

<style lang="scss">
.plotly * {
  /**
  * Disable selection when double-clicking legend
  */
  user-select: none;

  /**
  * Hide redundant title, included for PNG output
  */
  svg {
    .g-gtitle {
      display: none;
    }
  }
}
</style>
