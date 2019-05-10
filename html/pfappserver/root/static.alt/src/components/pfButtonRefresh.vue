<template>
  <button type="button" :aria-label="$t('Refresh')" :disabled="isLoading || disabled" class="pfButtonRefresh mx-3" @click="refresh"
    v-b-tooltip.hover.left.d300 :title="$t('Refresh [ALT+R]')">
    <icon name="redo-alt" :style="`transform: rotate(${rotate}deg)`"></icon>
  </button>
</template>

<script>
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pfButtonRefresh',
  data () {
    return {
      num: 0,
      disabled: false
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
