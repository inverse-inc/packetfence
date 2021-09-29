<template>
  <div>
    {{ value }}%
    <b-progress :max="100" height="4px">
      <b-progress-bar :value="value" :precision="2" :variant="level" :show-value="false"></b-progress-bar>
      <b-progress-bar :value="otherValue" :precision="2" :variant="level" :show-value="false" style="opacity: 0.2"></b-progress-bar>
    </b-progress>
  </div>
</template>

<script>
const props = {
  score: {
    type: [String, Number],
    default: 0
  },
  hideValue: {
    type: Boolean
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = props => {

  const {
    score
  } = toRefs(props)

  const value = computed(() => parseFloat(score.value) || 0)
  const otherValue = computed(() => 100 - value.value)
  const level = computed(() => {
    // See fingerbank-cloud-api.git/app/views/combinations/row.html.erb
    if (value.value < 33) {
      return 'danger'
    } else if (value.value < 66) {
      return 'warning'
    } else {
      return 'success'
    }
  })

  return {
    value,
    otherValue,
    level
  }
}

// @vue/component
export default {
  name: 'icon-score',
  props,
  setup
}
</script>
