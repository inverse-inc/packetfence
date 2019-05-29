<template>
  <embed :src="src" type="image/svg+xml" height="25" />
</template>

<script>
export default {
  name: 'badge',
  props: {
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
  },
  computed: {
    src () {
      return `/netdata/${this.ip}/api/v1/badge.svg?chart=${this.chart}&label=${encodeURIComponent(this.label)}&scale=100&refresh=10&label_color=${encodeURIComponent(this.colors.split(/ /)[0])}&value_color=gray`
    }
  }
}
</script>
