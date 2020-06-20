export default {
  name: 'mixin-form-model',
  model: {
    prop: 'value',
    event: 'input'
  },
  props: {
    value: {
      type: [String, Number],
      default: ''
    },
  },
  data() {
    return {
      localValue: this.value
    }
  },
  mounted() {
    const value = this.value
    if (value !== this.localValue) {
      this.localValue = value
    }
  },
  watch: {
    value (newValue) {
      if (newValue !== this.localValue) {
        this.localValue = newValue
      }
    }
  }
}
