<!--
https://github.com/bvaughn/progress-estimator
-->
<template>
    <b-progress class="fixed-top" height="4px" :value="percentage" v-show="visible"></b-progress>
</template>

<script>
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pf-progress',
  props: {
    active: {
      required: true
    }
  },
  data () {
    return {
      visible: false,
      percentage: 10,
      debounce: 300,
      lastStart: 0,
      lastDuration: 3000 // miliseconds
    }
  },
  watch: {
    active: {
      handler (after, before) {
        const _this = this
        if (!this.$debouncer) {
          this.$debouncer = createDebouncer()
        }
        if (after) {
          this.lastStart = performance.now()
          this.percentage = 10
          setTimeout(this.increasePercentage, this.lastDuration / 10)
          this.$debouncer({
            handler: () => {
              _this.visible = _this.active
            },
            time: this.debounce
          })
        } else {
          this.percentage = 100
          this.lastDuration = performance.now() - this.lastStart
          this.$debouncer({
            handler: () => {
              if (!_this.active) {
                _this.visible = false
              }
            },
            time: 1000 // 1 second
          })
        }
      },
      immediate: true
    }
  },
  methods: {
    increasePercentage () {
      if (this.percentage < 90) {
        this.percentage += 10
        setTimeout(this.increasePercentage, this.lastDuration / 10)
      } else if (this.percentage < 99) {
        this.percentage += 1
        setTimeout(this.increasePercentage, this.lastDuration / 10)
      } else if (this.percentage < 100) {
        this.percentage -= 9 // back to 90
        this.lastDuration *= 1.5
        setTimeout(this.increasePercentage, this.lastDuration / 10)
      }
    }
  }
}
</script>

<style lang="scss">
  .progress.fixed-top {
    background-color: $gray-700;
  }
</style>
