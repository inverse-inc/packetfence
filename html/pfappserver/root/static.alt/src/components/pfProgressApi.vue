<template>
  <b-progress class="fixed-top" height="4px" max="100" :value="percentage" v-show="visible"></b-progress>
</template>

<script>
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pf-progress-api',
  data () {
    return {
      visible: false,
      visibleTimeout: 1000 // 1.0 seconds
    }
  },
  methods: {
    show () {
      this.visible = true
    },
    hide () {
      if (!this.$debouncer) {
        this.$debouncer = createDebouncer()
      }
      this.$debouncer({
        handler: () => {
          if (!this.isLoading) {
            this.visible = false
          }
        },
        time: this.visibleTimeout
      })
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['performance/isLoading']
    },
    percentage () {
      return this.$store.getters['performance/getPercentage']
    }
  },
  watch: {
    isLoading: {
      handler (after, before) {
        if (after) {
          this.show()
        } else {
          this.hide()
        }
      },
      immediate: true
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

  .progress {
    overflow: visible !important;
  }
  .progress /deep/ .progress-bar {
    box-shadow: 0 0 10px rgba($primary,.7);
  }
</style>
