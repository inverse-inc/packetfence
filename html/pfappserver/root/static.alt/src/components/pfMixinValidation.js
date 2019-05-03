/**
 * Mixin for vuelidate form validation.
**/
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pfMixinValidation',
  props: {
    vuelidate: {
      type: Object,
      default: null
    },
    invalidFeedback: {
      default: null
    },
    highlightValid: {
      type: Boolean,
      default: false
    },
    validationDebounce: {
      type: Number,
      default: 300
    },
    filter: {
      type: RegExp,
      default: null
    },
    lastValidValue: {
      type: String,
      default: null
    },
    keyName: {
      type: String,
      default: null
    }
  },
  methods: {
    isValid () {
      if (this.vuelidate && this.vuelidate.$dirty) {
        if (this.vuelidate.$invalid) {
          return false
        } else if (this.highlightValid) {
          return true
        }
      }
      if (this.keyName in this.$store.state.session.formErrors) {
        return false
      }
      return null
    },
    validate () {
      const _this = this
      if (this.vuelidate && '$touch' in this.vuelidate) {
        this.$validationDebouncer({
          handler: () => {
            _this.vuelidate.$touch()
          },
          time: this.validationDebounce
        })
      }
    },
    onChange (event) {
      if (this.filter) {
        // this.value is one char behind, wait until next tick for our v-model to update
        this.$nextTick(() => {
          if (!this.value || this.value.length === 0) {
            this.lastValidValue = ''
          } else {
            if (this.filter.test(this.value)) {
              // good, remember
              this.lastValidValue = this.value
            } else {
              // bad, restore
              this.value = this.lastValidValue
            }
          }
        })
      }
    },
    stringifyFeedback (feedback) {
      if (feedback === null) return ''
      if (feedback instanceof Array) {
        let ret = ''
        feedback.forEach(f => {
          ret += ((ret !== '') ? ' ' : '') + this.stringifyFeedback(f)
        })
        return ret
      }
      if (feedback instanceof Object) {
        if (Object.values(feedback)[0] === true) {
          return Object.keys(feedback)[0]
        }
        return ''
      }
      return feedback
    },
    getInvalidFeedback () {
      let feedback = []
      if (this.vuelidate) {
        // automatically generated feedback
        if ('$params' in this.vuelidate) {
          Object.entries(this.vuelidate.$params).forEach(([param, validator]) => {
            if (this.vuelidate[param] === false) feedback.push(param)
          })
        }
      }
      if (feedback.length === 0 && this.invalidFeedback) {
        // manually defined feedback
        feedback.push(this.stringifyFeedback(this.invalidFeedback))
      }
      if (this.keyName in this.$store.state.session.formErrors) {
        // errors from last POST, PUT, PATCH or DELETE
        feedback.push(this.$store.state.session.formErrors[this.keyName])
      }
      return feedback.join('\n')
    }
  },
  created () {
    this.$validationDebouncer = createDebouncer()
  }
}
