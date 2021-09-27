<template>
  <div ref="plotlyRef" id="plotly" />
</template>

<script>
const layout = {
  margin: {
    l: 50,
    r: 50,
    b: 25,
    t: 50,
    pad: 0
  },
  font: {
    size: 10,
    color: '#444'
  },
  arrangement: 'freeform',
  hoveron: 'color'
}

const options = {
  type: 'parcats'
}

const props = {
  fields: {
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
import plotly from '@/utils/plotly'
import {
  colorsFull
} from '../config'
import { useSearchFactory } from '../_search'

const setup = props => {

  const {
    fields,
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
    const sFields = fields.value.split(':')
    const lastField = sFields[sFields.length - 1] // last field contains count
    const dimensions = sFields.slice(0, -1).map(label => {
      return {
        label,
        values: items.value.reduce((dimensions, item) => {
          const { [label]: value } = item
          return [ ...dimensions, value ]
        }, [])
      }
    })
    const counts = items.value.map(item => {
      const { [lastField]: count } = item
      return count
    })

    const data = [{ dimensions, counts, line: { color: colorsFull }, ...options }]
    plotly.react(plotlyRef.value, data, layout, { displayModeBar: true, scrollZoom: true, displaylogo: false, showLink: false })
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
  name: 'base-chart-parallel',
  props,
  setup
}
</script>
