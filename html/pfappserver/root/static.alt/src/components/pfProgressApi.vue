<template>
  <b-progress class="fixed-top" height="4px" max="100" :value="percentage" v-show="visible"></b-progress>
</template>

<script>
import apiCall from '@/utils/api'
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pf-progress-api',
  data () {
    return {
      visible: true,
      debounce: 300,
      lastActive: 0,
      onParPercentile: 75, // @ the estimated time set the progress bar to this %
      percentage: 0,
      interval: null,
      $debouncer: createDebouncer()
    }
  },
  methods: {
    setPercentage () {
      // f(x) = 1 - e^(-k * i)
      //   k = -ln(1 - x) / i
      const eta = apiCall.queue.getEta()
      const now = (new Date()).getTime()
      const x = (eta - this.lastActive)
      const i = (now - this.lastActive)
      const k = -(Math.log(1 - (this.onParPercentile / 100)) / x)
      const p = (1 - Math.exp(-k * i))
      this.percentage = (isNaN(p)) ? 100 : (p * 100)
    },
    show () {
      const _this = this
      if (!this.$debouncer) {
        this.$debouncer = createDebouncer()
      }
      this.visible = true
      this.lastActive = (new Date()).getTime()
      if (!this.interval) {
        this.interval = setInterval(this.setPercentage(), 100)
      }
    },
    hide () {
      const _this = this
      clearInterval(this.interval)
      this.percentage = 100
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
  computed: {
    queue: {
      get () {
        return apiCall.queue.cache
      },
      set (newCache) {
        apiCall.queue.cache = newCache
      }
    },
    active () {
      return this.queue.length > 0
    },
    variant () {
      return 'success'
    }
  },
  watch: {
    active: {
      handler (after, before) {
        if (after) {
          this.show()
        } else {
          this.hide()
        }
      },
      immediate: true
    },
    queue: {
      handler (after, before) {
        if (after.length === 0) {
          this.hide()
        } else {
          this.setPercentage()
        }
      },
      deep: true
    }
  }
}
</script>

<style lang="scss" scoped>
  @import "../../node_modules/bootstrap/scss/functions";
  @import "../styles/variables";

  .fixed-top {
    background-color: $gray-700;
  }
</style>
