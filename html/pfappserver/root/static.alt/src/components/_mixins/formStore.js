import { createDebouncer } from 'promised-debounce'

export default {
  name: 'form-store',
  props: {
    formStoreName: {
      type: String,
      default: null,
      required: false
    },
    formNamespace: {
      type: String,
      default: null,
      required: false
    },
    state: {
      type: Boolean,
      default: null
    },
    stateMap: {
      type: Object,
      default: () => { return { false: false, true: null } }
    },
    invalidFeedback: {
      type: String
    },
    validFeedback: {
      type: String
    }
  },
  data () {
    return {
      $inputDebouncer: false
    }
  },
  computed: {
    vModel () {
      return this.$store.getters[`${this.formStoreName}/$vModel`]
    },
    inputDebounceTimeMs () {
      return this.$store.getters[`${this.formStoreName}/$inputDebounceTimeMs`]
    },
    invalidFeedback () {
      return this.$store.getters[`${this.formStoreName}/$feedbackNS`](this.formNamespace)
    },
    localValue: {
      get () {
        return this.vModel[this.formNamespace]
      },
      set (newValue) {
        if (!this.$inputDebouncer) {
          this.$inputDebouncer = createDebouncer()
        }
        this.$inputDebouncer({
          handler: () => {
            this.vModel[this.formNamespace] = newValue
          },
          time: this.inputDebounceTimeMs
        })
      }
    },
    localState () {
      const { $invalid, $pending } = this.$store.getters[`${this.formStoreName}/$stateNS`](this.formNamespace)
      return this.stateMap[!$invalid || $pending]
    },
    localStateIfInvalidFeedback () {
      return (this.invalidFeedback)
        ? this.localState
        : null
    },
    localAnyState () {
      const { $model, $each } = this.$store.getters[`${this.formStoreName}/$vuelidateNS`](this.formNamespace)
      for (let item of Object.keys($model || {})) {
        const { [item]: { $invalid = false } = {} } = $each || {}
        if ($invalid) return this.stateMap[false]
      }
      return this.stateMap[true]
    },
    localInvalidFeedback () {
      return this.invalidFeedback
    }
  }
}
