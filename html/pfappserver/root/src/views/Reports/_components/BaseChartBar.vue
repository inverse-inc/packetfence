<template>
  <div ref="plotlyRef" />
</template>

<script>
// https://plot.ly/javascript/reference/
// https://plot.ly/javascript/plotlyjs-function-reference/
import Plotly from 'plotly.js-basic-dist-min'
require('typeface-b612-mono') // custom pixel font

const layout = {
  margin: {
    l: 25,
    r: 25,
    b: 100,
    t: 50,
    pad: 0
  },
  font: {
    size: 10,
    color: '#444'
  }
}

const options = {
  type: 'bar',
  hoverinfo: 'label+percent',
  marker: {
    line: {
      width: 0.5
    }
  },
  textinfo: 'label'
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
    let color = colorsFull
    let x
    let y
    if (items.value.length === 0) {
      // no data
      color = colorsNull
      x = [ i18n.t('No Data') ]
      y = [ 0 ]
    } else {
      x = items.value.map(item => {
        const { [field.value]: label } = item
        return label
      })
      y = items.value.map(item => {
        const { [count.value]: value } = item
        return value
      })
    }
    options.marker = { ...options.marker, color }
    const data = [{ x, y, ...options }]
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
  name: 'base-chart-bar',
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
