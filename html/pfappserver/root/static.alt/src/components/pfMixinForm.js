/**
 * Mixin for FormStore module.
**/
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
  computed: {
    vModel () {
      return this.$store.getters[`${this.formStoreName}/$vModel`]
    },
    formStoreValue: {
      get () {
        return this.vModel[this.formNamespace]
      },
      set (newValue) {
        this.vModel[this.formNamespace] = newValue
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
        return this.stateMap[!this.formStoreState.$invalid] // use FormStore
      } else {
        return this.stateMap[this.state] // use native (state)
      }
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
