<template>
  <div ref="plotlyRef" />
</template>

<script>
// https://plot.ly/javascript/reference/
// https://plot.ly/javascript/plotlyjs-function-reference/
import Plotly from 'plotly.js-basic-dist-min'

const props = {
  field: {
    type: String
  },
  count: {
    type: String
  },
  meta: {
    type: Object
  },
  report: {
    type: Object
  }
}

import { ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  colorsFull,
  colorsNull,
  layout,
  options
} from '../config'
import { useSearchFactory } from '../_search'

const setup = props => {

  const {
    field,
    count,
    meta,
    report
  } = toRefs(props)

  const plotlyRef = ref(null)

  let debouncer
  const _queueRender = () => {
      // debounce async calls to render
    if (debouncer)
      clearTimeout(debouncer)
    debouncer = setTimeout(_render, 100)
  }

  const _render = () => {
    if (!plotlyRef.value)
      return
    let colors = colorsFull
    let values
    let labels
    if (items.value.length === 0) {
      // no data
      colors = colorsNull
      values = [ 100 ]
      labels = [ i18n.t('No Data') ]
    } else {
      values = items.value.map(item => {
        const { [count.value]: value } = item
        return value
      })
      labels = items.value.map(item => {
        const { [field.value]: label } = item
        return label
      })
    }
    options.pie.marker = { ...options.pie.marker, colors }
    const data = [{ values, labels, ...options.pie }]
    Plotly.react(plotlyRef.value, data, layout.pie, { displayModeBar: true, scrollZoom: true, displaylogo: false, showLink: false })
  }

  const useSearch = useSearchFactory(report, meta)
  const search = useSearch()
  const {
    items
  } = toRefs(search)

  watch(items, _queueRender, { immediate: true })

  return {
    plotlyRef
  }
}

// @vue/component
export default {
  name: 'base-chart-pie',
  props,
  setup
}
</script>

<style lang="scss" scoped>
/**
 * Disable selection when double-clicking legend
 */
.plotly * {
  user-select: none;
}
</style>
