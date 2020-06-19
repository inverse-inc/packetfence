/**
 * Mixin for FormStore module.
**/
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pf-mixin-form',
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
      type: String,
      default: null
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
    formStoreValue: {
      get () {
        return (this.formNamespace)
          ? this.vModel[this.formNamespace]
          : null
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
    formStoreState () {
      return this.$store.getters[`${this.formStoreName}/$stateNS`](this.formNamespace)
    },
    formStoreInvalidFeedback () {
      return this.$store.getters[`${this.formStoreName}/$feedbackNS`](this.formNamespace)
    },
    inputState () {
      if (this.formStoreName) {
        return this.stateMap[!this.formStoreState.$invalid || this.formStoreState.$pending] // use FormStore
      } else {
        return this.stateMap[this.state] // use native (state)
      }
    },
    inputStateIfInvalidFeedback () {
      if (this.invalidFeedback) {
        return this.inputState
      }
      return null
    },
    inputAnyState () {
      if (this.formStoreName) {
        const { $model, $each } = this.$store.getters[`${this.formStoreName}/$vuelidateNS`](this.formNamespace) // use FormStore
        for (let item of Object.keys($model || {})) {
          const { [item]: { $invalid = false } = {} } = $each || {}
          if ($invalid) return this.stateMap[false]
        }
        return this.stateMap[true]
      } else {
        return this.stateMap[this.state] // use native (state)
      }
    },
    inputInvalidFeedback () {
      if (this.formStoreName) {
        return this.formStoreInvalidFeedback // use FormStore
      } else {
        return this.invalidFeedback // use native (invalidFeedback)
      }
    }
  }
}
