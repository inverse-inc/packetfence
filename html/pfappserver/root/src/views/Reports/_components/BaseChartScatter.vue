<template>
  <div ref="plotlyRef" id="plotly" />
</template>

<script>
const layout = {
  margin: {
    l: 25,
    r: 25,
    b: 25,
    t: 50,
    pad: 0
  },
  font: {
    size: 10,
    color: '#444'
  },
  hoveron: 'points+fills',
  connectgaps: false
}

const stepmode = 'backward'
const rangeselector = {
  buttons: [
    { count: 30, label: '30m', step: 'minute', stepmode },
    { count: 1, label: '1h', step: 'hour', stepmode },
    { count: 6, label: '6h', step: 'hour', stepmode },
    { count: 12, label: '12h', step: 'hour', stepmode },
    { count: 1, label: '1D', step: 'day', stepmode },
    { count: 1, label: '1W', step: 'week', stepmode },
    { count: 2, label: '2W', step: 'week', stepmode },
    { count: 1, label: '1M', step: 'month', stepmode },
    { count: 2, label: '2M', step: 'month', stepmode },
    { count: 6, label: '6M', step: 'month', stepmode },
    { count: 1, label: '1Y', step: 'year', stepmode },
    { step: 'all' }
  ]
}

const dimensions = [
  {
    name: 'by year',
    normalize: 'YYYY-01-01 00:00:00'
  },
  {
    name: 'by month',
    normalize: 'YYYY-MM-01 00:00:00'
  },
  {
    name: 'by day',
    normalize: 'YYYY-MM-DD 00:00:00'
  },
  {
    name: 'by hour',
    normalize: 'YYYY-MM-DD HH:00:00'
  },
  {
    name: 'by minute',
    normalize: 'YYYY-MM-DD HH:mm:00'
  },
  {
    name: 'by second',
    normalize: 'YYYY-MM-DD HH:mm:ss'
  }
]

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

import { parse, format } from 'date-fns'
import { computed, onBeforeUnmount, onMounted, ref, toRefs, watch } from '@vue/composition-api'
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

  const title = computed(() => {
    let { description, has_date_range, start_date, end_date } = meta.value
    if (has_date_range) {
      if (start_date)
        description += ` from ${start_date}`
      if (end_date)
        description += ` to ${end_date}`
    }
    return description
  })

  const plotlyRef = ref(null)

  const filteredItems = computed(() => {
    return items.value
      .filter(item => {
        const { [fields.value]: value } = item
        return (value && value[0] !== '0') // ignore zero dates
      })
      .sort((a, b) => {
        const { [fields.value]: valueA } = a
        const { [fields.value]: valueB } = b
        return valueA.localeCompare(valueB)
      })
  })

  const minDate = computed(() => {
    return filteredItems.value.reduce((min, item) => {
      const { [fields.value]: value } = item
      const parsed = parse(value, 'YYYY-MM-DD HH:mm:ss')
      const date = format(parsed, 'YYYY-MM-DD HH:mm:ss')
      return (!min || date < min) ? date : min
    }, '')
  })

  const maxDate = computed(() => {
    return filteredItems.value.reduce((max, item) => {
      const { [fields.value]: value } = item
      const parsed = parse(value, 'YYYY-MM-DD HH:mm:ss')
      const date = format(parsed, 'YYYY-MM-DD HH:mm:ss')
      return (!max || date > max) ? date : max
    }, '')
  })

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

    const data = dimensions.map((dimension, index) => {
      const { name, normalize } = dimension
      const color = colorsFull[index]
      const associated = filteredItems.value.reduce((associated, item) => {
        const { [fields.value]: value } = item
        if (value && value[0] !== '0') { // ignore zero dates
          const parsed = parse(value, 'YYYY-MM-DD HH:mm:ss')
          let date = format(parsed, normalize)
          if (date < minDate.value) {
            // limit re-scaled date to within min/max, otherwise date pollutes the charts minimum y-scale
            date = minDate.value
          }
          if (date in associated)
            associated[date]++
          else
            associated[date] = 1
        }
        return associated
      }, {})
      const x = Object.keys(associated)
      const y = Object.values(associated)
      return {
        type: 'scatter',
        mode: 'lines+markers+text',
        name,
        x,
        y,
        line: { color, shape: 'spline', smoothing: 0.5 }
      }
    })
    const range = (minDate.value && maxDate.value)
      ? [minDate.value, maxDate.value]
      : []
    const rangeslider = { range }
    const xaxis = {
      autorange: false,
      range,
      rangeselector,
      rangeslider,
      type: 'date'
    }
    plotly.react(plotlyRef.value, data, { ...layout, rangeslider: { range }, xaxis, yaxis: { autorange: true, type: 'log' }, title: title.value }, { displayModeBar: true, scrollZoom: true, displaylogo: false, showLink: false })
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
  name: 'base-chart-scatter',
  props,
  setup
}
</script>
