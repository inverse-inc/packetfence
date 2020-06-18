import { BFormInput } from 'bootstrap-vue'
import mixinForm from '@/components/pfMixinForm'
import mixinSass from './mixin.scss' // mixin scoped sass

// @vue/component
export default {
  name: 'pf-input',
  mixins: [
    mixinForm,
    mixinSass
  ],
  props: {
    value: {
      type: [String, Number],
      default: ''
    }
  },
  data () {
    return {}
  },
  computed: {
    localValue: {
      get () {
        if (this.formStoreName) {
          return this.formStoreValue // use FormStore
        } else {
          return this.value // use native (v-model)
        }
      },
      set (newValue = null) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.value = newValue
        }
      }
    }
  },
  watch: {},
  mounted () {},
  deactivated () {},
  activated () {},
  beforeDestroy () {},
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
      ref: 'pf-input',
      staticClass: null,
      class: {
        'pf-input': true
      },
      directives: [ // https://vuejs.org/v2/guide/custom-directive.html
        {
          name: 'model',
          rawName: 'v-model',
          value: this.localValue,
          expression: 'localValue'
        }
      ],
      attrs: this.$attrs, // forward $attrs
      props: {
        ...this.$props, // forward $props
        value: this.localValue
      },
      domProps: {},
      on: {
        ...this.$listeners, // forward $listeners
        input: this.onInput,
        change: this.onChange
      }
    })
  }
}
