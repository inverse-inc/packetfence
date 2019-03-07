<template>
  <b-form :class="['d-inline-flex', {'flex-row-reverse': reverse}]" @submit.prevent="onConfirm($event)" inline>
    <b-input-group v-if="interrupt">
      <b-input
        ref="input"
        type="text"
        v-model="inputValue"
        :size="size"
        @focus="suspendInterrupt($event)"
        @blur="startInterrupt($event)" />
      <b-button
        type="submit"
        :variant="variant"
        :size="size"
        slot="append">
        <slot>{{ $t('Confirm') }}</slot>
      </b-button>
    </b-input-group>
    <b-button
      v-else
      type="button"
      :variant="variant"
      :size="size"
      :disabled="disabled"
      @click.stop="startInterrupt($event)">
      <slot>{{ $t('Confirm') }}</slot>
    </b-button>
  </b-form>
</template>

<script>
export default {
  name: 'pf-button-prompt',
  props: {
    value: {
      default: null
    },
    size: {
      type: String,
      default: ''
    },
    variant: {
      type: String,
      default: 'outline-secondary'
    },
    visible: {
      type: Boolean,
      default: false
    },
    timeout: {
      type: Number,
      default: 6000
    },
    disabled: {
      type: Boolean,
      default: false
    },
    reverse: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      interrupt: false
    }
  },
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    }
  },
  methods: {
    startInterrupt (event) {
      if (this.timerStop) clearTimeout(this.timerStop)
      this.interrupt = true
      this.$nextTick(() => {
        this.$refs.input.$el.focus()
      })
      this.timerStop = setTimeout(this.stopInterrupt, this.timeout)
    },
    suspendInterrupt (event) {
      if (this.timerStop) clearTimeout(this.timerStop)
    },
    stopInterrupt (event) {
      if (this.timerStop) clearTimeout(this.timerStop)
      if (this.inputValue) {
        // Keep the input field visible
        this.startInterrupt(event)
      } else {
        this.interrupt = false
      }
    },
    onConfirm (event) {
      if (this.timerStop) clearTimeout(this.timerStop)
      this.interrupt = false
      // emit to parent
      this.$emit('on-confirm', event)
    }
  },
  beforeDestroy () {
    if (this.timerStop) {
      clearTimeout(this.timerStop)
    }
  }
}
</script>
