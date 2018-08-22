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
export default {
  name: 'pf-fingerbank-score',
  props: {
    score: {
      type: Number,
      default: 0
    },
    hideValue: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    value () {
      return parseFloat(this.score) || 0
    },
    otherValue () {
      return 100 - this.value
    },
    level () {
      // See fingerbank-cloud-api.git/app/views/combinations/row.html.erb
      if (this.value < 33) {
        return 'danger'
      } else if (this.value < 66) {
        return 'warning'
      } else {
        return 'success'
      }
    }
  }
}
</script>

