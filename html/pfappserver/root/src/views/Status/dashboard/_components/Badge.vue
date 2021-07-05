<template>
  <embed :src="src" type="image/svg+xml" height="25" />
</template>

<script>
const props = {
  ip: {
    type: String,
    default: null,
    required: true
  },
  chart: {
    type: String,
    default: '',
    required: true
  },
  label: {
    type: String,
    default: '',
    required: true
  },
  colors: {
    type: String,
    default: 'blue'
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = (props) => {
  const {
    ip,
    chart,
    label,
    colors
  } = toRefs(props)

  const src = computed(() => `/netdata/${ip.value}/api/v1/badge.svg?chart=${chart.value}&label=${encodeURIComponent(label.value)}&scale=100&refresh=10&label_color=${encodeURIComponent(colors.value.split(/ /)[0])}&value_color=gray`)

  return {
    src
  }
}

// @vue/component
export default {
  name: 'badge',
  props,
  setup
}
</script>
