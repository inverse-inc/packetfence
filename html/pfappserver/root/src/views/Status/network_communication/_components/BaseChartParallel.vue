<template>
  <component :is="componentIs" v-bind="componentProps" ref="plotlyRef" id="plotly" />
</template>

<script>
const layout = {
  height: 800,
  margin: {
    l: 150,
    r: 150,
    b: 50,
    t: 50,
    pad: 0
  },
  font: {
    size: 10,
    color: '#444'
  },
  arrangement: 'freeform',
  autosize: true,
}

const options = {
  type: 'parcats'
}

import {
    BaseTableEmpty
} from '@/components/new/'
const components = {
  BaseTableEmpty
}

const props = {
  autoHeight: {
    type: Boolean
  },
  dimensions: {
    type: Array
  },
  color: {
    type: Array
  },
  counts: {
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

const setup = (props) => {

  const {
    autoHeight,
    dimensions,
    color,
    counts,
    isLoading,
    title,
    settings
  } = toRefs(props)

  const plotlyRef = ref(null)

  const layoutRef = computed(() => {
    if (autoHeight.value) {
      const { margin: { t, b  } = {} } = layout
      const count = Math.max(
        [...new Set(dimensions.value[0].values)].length,
        [...new Set(dimensions.value[1].values)].length,
        [...new Set(dimensions.value[2].values)].length
      )
      const height = (10 * count) + t + b
      return {
        ...layout,
        height
      }
    }
    return layout
  })

  let debouncer
  const _queueRender = () => {
      // debounce async calls to render
    if (debouncer)
      clearTimeout(debouncer)
    debouncer = setTimeout(_render, 100)
  }

  const _render = () => {
    if (!plotlyRef.value || dimensions.value.length === 0)
      return
    const data = [{
      dimensions: dimensions.value,
      counts: counts.value,
      line: {
        color: color.value,
        shape: 'hspline',
        hoveron: 'color'
      },
      ...options
    }]
    const { locale } = i18n
    const { plotlyImageType: format = 'png' } = settings.value
    const toImageButtonOptions = { filename: title.value, format }
    plotly.react(plotlyRef.value, data, { ...layoutRef.value, title: title.value }, { locale, toImageButtonOptions, ...config })
  }

  watch([dimensions, color, counts, title, settings, () => i18n.locale], _queueRender, { immediate: true })

  onMounted(() => window.addEventListener('resize', _queueRender))
  onBeforeUnmount(() => window.removeEventListener('resize', _queueRender))

  const componentIs = computed(() => {
    return (!isLoading.value && dimensions.value.length > 0)
      ? 'div' // plotly
      : BaseTableEmpty
  })
  const componentProps = computed(() => ({
    isLoading: isLoading.value,
    text: i18n.t('No results to display'),
    icon: 'chart-line',
    style: `height: ${layoutRef.value.height}px`,
  }))

  return {
    plotlyRef,
    componentIs,
    componentProps
  }
}

// @vue/component
export default {
  name: 'base-chart-parallel',
  components,
  props,
  setup
}
</script>
