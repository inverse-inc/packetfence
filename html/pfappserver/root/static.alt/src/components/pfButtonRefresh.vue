<template>
  <button type="button" :aria-label="$t('Refresh')" :disabled="isLoading || disabled"
    class="pfButtonRefresh mx-3"
    v-b-tooltip.hover.left.d300 :title="$t('Refresh [ALT+R]')"
    @click="click"
  >
    <icon v-if="interval" name="history" :style="`transform: rotate(${rotate}deg) scaleX(-1)`" :class="{ 'text-primary': ctrlKey }"></icon>
    <icon v-else name="redo" :style="`transform: rotate(${rotate}deg)`" :class="{ 'text-primary': ctrlKey }"></icon>
  </button>
</template>

<script>
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pfButtonRefresh',
  data () {
    return {
      num: 0,
      disabled: false,
      interval: false,
      timeout: 15000
    }
  },
  props: {
    isLoading: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    rotate () {
      return this.num * 360
    },
    ctrlKey () {
      return this.$store.getters['events/ctrlKey']
    },
    altRKey () {
      return this.$store.getters['events/altRKey']
    }
  },
  methods: {
    click (event) {
      if (this.ctrlKey) {
        if (this.interval) { // clear interval
          clearInterval(this.interval)
          this.interval = false
        } else { // create interval
          this.interval = setInterval(this.refresh, this.timeout)
          this.refresh(event)
        }
      } else {
        if (this.interval) { // reset interval
          clearInterval(this.interval)
          this.interval = setInterval(this.refresh, this.timeout)
        }
        this.refresh(event)
      }
    },
    refresh (event) {
      this.disabled = true
      if (!this.$debouncer) {
        this.$debouncer = createDebouncer()
      }
      this.$debouncer({
        handler: () => {
          this.num++
          this.$emit('refresh', event)
          this.disabled = false
        },
        time: 300 // 300 milli-seconds
      })
    }
  },
  beforeDestroy () {
    if (this.interval) {
      clearInterval(this.interval)
    }
  },
  watch: {
    altRKey (pressed) {
      if (pressed) {
        this.refresh(event)
      }
    }
  }
}
</script>

<style lang="scss">
button {
  &.pfButtonRefresh {
    padding: 0;
    background-color: transparent;
    border: 0;
    outline: 0;
  }
  svg {
    transition: 300ms ease all;
  }
}
.pfButtonRefresh {
  float: right;
  font-size: 1.35rem;
  font-weight: 700;
  line-height: 1;
  color: #000;
  text-shadow: 0 1px 0 #fff;
  opacity: .5;
}
</style>
