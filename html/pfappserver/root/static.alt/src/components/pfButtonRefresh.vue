<template>
  <button type="button" :aria-label="$t('Refresh')" :disabled="isLoading || disabled"
    class="pfButtonRefresh mx-3" :class="{ 'text-primary': hilight }"
    v-b-tooltip.hover.left.d300 :title="$t('Refresh [ALT+R]')"
    @click="click"
  >
    <icon name="redo-alt" :style="`transform: rotate(${rotate}deg)`"></icon>
  </button>
</template>

<script>
import { createDebouncer } from 'promised-debounce'
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'

export default {
  name: 'pfButtonRefresh',
  mixins: [
    pfMixinCtrlKey
  ],
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
      return this.num * 360;
    },
    hilight () {
      return this.ctrlKey || this.interval
    }
  },
  methods: {
    onKey (event) {
      switch (true) {
        case (event.altKey && event.keyCode === 82): // ALT+R
          event.preventDefault()
          this.refresh(event)
          break
      }
    },
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
  mounted () {
    document.addEventListener('keydown', this.onKey)
  },
  beforeDestroy () {
    document.removeEventListener('keydown', this.onKey)
    if (this.interval) {
      clearInterval(this.interval)
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
