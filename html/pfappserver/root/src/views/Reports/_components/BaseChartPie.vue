<template>
  <div ref="plotlyRef" />
</template>

<script>
// https://plot.ly/javascript/reference/
// https://plot.ly/javascript/plotlyjs-function-reference/
import Plotly from 'plotly.js-basic-dist-min'

const layout = {
  autosize: true,
  hoverdistance: 100,
  hovermode: 'closest',
  spikedistance: 100,
  legend: {
    bgcolor: '#eee',
    bordercolor: '#eee',
    borderwidth: 10,
    orientation: 'v',
    xanchor: 'center',
    x: 1,
    y: 0.5
  },
  margin: {
    l: 25,
    r: 25,
    b: 25,
    t: 25,
    pad: 25,
    autoexpand: true
  },
  font: {
    size: 10,
    color: '#444'
  }
}

const options = {
  type: 'pie',
  direction: 'clockwise',
  domain: {
    x: [0, 1],
    y: [0, 1]
  },
  hoverinfo: 'label+percent',
  hole: 0.25,
  marker: {
    line: {
      width: 0.5
    }
  },
  pull: 0,
  rotation: -90,
  textinfo: 'label',
  textposition: 'outside'
}

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

import { onBeforeUnmount, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  colorsFull,
  colorsNull
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
    options.marker = { ...options.marker, colors }
    const data = [{ values, labels, ...options }]
    Plotly.react(plotlyRef.value, data, layout, { displayModeBar: true, scrollZoom: true, displaylogo: false, showLink: false })
  }

  const useSearch = useSearchFactory(report, meta)
  const search = useSearch()
  const {
    items
  } = toRefs(search)

  watch(items, _queueRender, { immediate: true })

  onMounted(() => window.addEventListener('resize', _queueRender))
  onBeforeUnmount(() => window.removeEventListener('resize', _queueRender))

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

<style lang="scss">
/**
 * Disable selection when double-clicking legend
 */
.plotly * {
  user-select: none;
}
</style>
