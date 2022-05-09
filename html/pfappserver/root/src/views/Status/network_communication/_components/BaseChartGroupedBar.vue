<template>
  <component :is="componentIs" v-bind="componentProps" ref="plotlyRef" id="plotly" />
</template>

<script>
const layout = {
  barmode: 'stack',
  bargap: 0,
  bargroupgap: 0,
  height: 800,
  margin: {
    l: 25,
    r: 25,
    b: 200,
    t: 100,
    pad: 0
  },
  font: {
    size: 10,
    color: '#444'
  },
  arrangement: 'freeform',
  autosize: true,
  showlegend: false,
  xaxis: {
    tickangle: 90,
  },
}

import {
    BaseTableEmpty
} from '@/components/new/'
const components = {
  BaseTableEmpty
}

const props = {
  traces: {
    type: Array
  },
  isLoading: {
    type: Boolean
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
  colorsFull
} from '../config'

const setup = (props, context) => {

  const {
    traces,
    isLoading,
    title,
    settings
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
    if (!plotlyRef.value || traces.value.length === 0)
      return
    const { locale } = i18n
    const { plotlyImageType: format = 'png' } = settings.value
    const toImageButtonOptions = { filename: title.value, format }
    plotly.react(plotlyRef.value, traces.value, { ...layout, title: title.value }, { locale, toImageButtonOptions, ...config })
  }

  watch([traces, title, settings, () => i18n.locale], _queueRender, { immediate: true })

  onMounted(() => window.addEventListener('resize', _queueRender))
  onBeforeUnmount(() => window.removeEventListener('resize', _queueRender))

  const componentIs = computed(() => {
    return (!isLoading.value && traces.value.length > 0)
      ? 'div' // plotly
      : BaseTableEmpty
  })
  const componentProps = computed(() => ({
    isLoading: isLoading.value,
    text: i18n.t('No results to display'),
    icon: 'chart-line',
    style: `height: ${layout.height}px`,
  }))

  return {
    plotlyRef,
    componentIs,
    componentProps
  }
}

// @vue/component
export default {
  name: 'base-chart-grouped-bar',
  components,
  props,
  setup
}
</script>
