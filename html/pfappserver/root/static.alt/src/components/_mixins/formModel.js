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
      inputValue: this.value
    }
  },
  mounted() {
    const value = this.value
    if (value !== this.inputValue) {
      this.inputValue = value
    }
  },
  watch: {
    value (newValue) {
      if (newValue !== this.inputValue) {
        this.inputValue = newValue
      }
    }
  },
  computed: {
    localValue () { // overloaded through inheritance
      return this.inputValue
    }
  }
}
