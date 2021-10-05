<template>
  <component :is="componentIs" v-bind="componentProps" ref="plotlyRef" id="plotly" />
</template>
<script>
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
    t: 50,
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

import {
    BaseTableEmpty
} from '@/components/new/'
const components = {
  BaseTableEmpty
}

const props = {
  fields: {
    type: String
  },
  meta: {
    type: Object
  },
  title: {
    type: String
  },
  settings: {
    type: Object
  }
}

import { computed, onBeforeUnmount, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import plotly, { config } from '@/utils/plotly'
import {
  colorsFull,
  colorsNull
} from '../config'
import { useSearchFactory } from '../_search'

const setup = props => {

  const {
    fields,
    meta,
    title,
    settings
  } = toRefs(props)

  const field = computed(() => fields.value.split(':')[0])
  const count = computed(() => fields.value.split(':')[1])
  const titleWithDates = computed(() => {
    let { has_date_range, start_date, end_date } = meta.value
    let _title = title.value
    if (has_date_range) {
      if (start_date)
        _title += ` from ${start_date}`
      if (end_date)
        _title += ` to ${end_date}`
    }
    return _title
  })

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
    const { locale } = i18n
    const { plotlyImageType: format = 'png' } = settings.value
    const toImageButtonOptions = { filename: titleWithDates.value, format }
    plotly.react(plotlyRef.value, data, { ...layout, title: titleWithDates.value }, { locale, toImageButtonOptions, ...config })
  }

  const useSearch = useSearchFactory(meta)
  const search = useSearch()
  const {
    items,
    isLoading
  } = toRefs(search)

  watch([items, () => i18n.locale], _queueRender, { immediate: true })

  onMounted(() => window.addEventListener('resize', _queueRender))
  onBeforeUnmount(() => window.removeEventListener('resize', _queueRender))

  const componentIs = computed(() => {
    return (!isLoading.value && items.value.length > 0)
      ? 'div' // plotly
      : BaseTableEmpty
  })
  const componentProps = computed(() => ({
    isLoading: isLoading.value,
    text: i18n.t('No results to display'),
    icon: 'chart-pie'
  }))

  return {
    plotlyRef,
    componentIs,
    componentProps
  }
}

// @vue/component
export default {
  name: 'base-chart-pie',
  components,
  props,
  setup
}
</script>