import { BFormInput } from 'bootstrap-vue'
import mixinScss from './mixin.scss' // mixin scoped scss
import {
  mixinFormHandlers,
  mixinFormModel
} from '@/components/_mixins/'

export const defaultProps = {
  disabled: {
    type: Boolean,
    disabled: false
  },
  placeholder: {
    type: String,
    default: null
  },
  readonly: {
    type: Boolean,
    default: false
  },
  type: {
    type: String,
    default: 'text'
  }
}

// @vue/component
export default {
  name: 'pf-input',
  mixins: [
    mixinFormHandlers,
    mixinFormModel, // uses v-model
    mixinScss
  ],
  props: {
    value: {
      type: [String, Number],
      default: ''
    },
    ...defaultProps
  },
  data () {
    return {}
  },
  computed: {},
  watch: {},
  mounted () {},
  deactivated () {},
  activated () {},
  beforeUnmount () {},
  methods: {
    focus () {
      this.$refs.input.focus()
    },
    onInput (event) {
      this.$emit('input', event) // bubble
      this.localValue = event
    },
    onChange (event) {
      this.$emit('change', event) // bubble
      this.localValue = event
    }
  },
  render (h) { // https://vuejs.org/v2/guide/render-function.html
    return h(BFormInput, {
      ref: 'input',
      staticClass: 'pf-input',
      attrs: this.$attrs, // forward $attrs
      props: {
        ...this.$props, // forward $props
        value: this.localValue
      },
      on: {
        input: this.onInput,
        change: this.onChange
      }
    })
  }
}
