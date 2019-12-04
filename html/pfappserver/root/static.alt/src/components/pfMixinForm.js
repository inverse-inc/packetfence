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
    }
  }
}
