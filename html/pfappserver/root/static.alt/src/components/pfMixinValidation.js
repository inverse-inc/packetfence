/**
 * Mixin for vuelidate form validation.
**/
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pf-mixin-validation',
  props: {
    vuelidate: {
      type: Object,
      default: undefined
    },
    invalidFeedback: {
      default: undefined
    },
    highlightValid: {
      type: Boolean,
      default: undefined
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
  data () {
    return {
      validDebouncerTime: 300,
      validDebouncer: createDebouncer(),
      validState: undefined, // true = is-valid (green-border), false = not-valid (red-border), null = none (no-border)
      feedbackDebouncerTime: 1500,
      feedbackDebouncer: createDebouncer(),
      feedbackState: undefined,
      vuelidateDebouncerTime: 300,
      vuelidateDebouncer: createDebouncer()
    }
  },
  methods: {
    isValid () {
      this.validDebouncer({
        handler: () => {
          if (this.vuelidate && this.vuelidate.$dirty) {
            if (this.vuelidate.$anyError) {
              this.$set(this, 'validState', false) // red border
              return
            } else if (this.highlightValid) {
              this.$set(this, 'validState', true) // green border
              return
            }
          }
          if (this.keyName in this.$store.state.session.formErrors) {
            this.$set(this, 'validState', false) // red border
            return
          }
          this.$set(this, 'validState', null) // no border
        },
        time: this.validDebouncerTime
      })
      return this.validState
    },
    validate () {
      if (this.vuelidate && '$touch' in this.vuelidate) {
        this.vuelidateDebouncer({
          handler: () => {
            this.vuelidate.$touch()
          },
          time: this.vuelidateDebouncerTime
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
      this.feedbackDebouncer({
        handler: () => {
          let feedback = []
          const {
            validState = null,
            vuelidate: {
              $params = null
            } = {},
            invalidFeedback = null,
            $store: {
              state: {
                session: {
                  formErrors: {
                    [this.keyName]: formErrors = null
                  } = {}
                } = {}
              } = {}
            } = {}
          } = this
          if (validState === false && $params) { // automatically generated feedback
            Object.entries($params).forEach(([param, validator]) => {
              if (this.vuelidate[param] === false) feedback.push(param)
            })
          }
          if (invalidFeedback) { // manually defined feedback
            feedback.push(this.stringifyFeedback(invalidFeedback))
          }
          if (formErrors) { // server defined errors from last POST, PUT, PATCH or DELETE
            feedback.push(formErrors)
          }
          this.feedbackState = feedback.join('\n')
        },
        time: this.feedbackDebouncerTime
      })
      return this.feedbackState
    }
  },
  created () {
    this.$set(this, 'validState', null) // make reactive
  },
  watch: {
    inputValue: {
      handler (a, b) {
        if (JSON.stringify(a) !== JSON.stringify(b)) {
          this.isValid()
        }
      },
      deep: true,
      immediate: true
    },
    vuelidate: {
      handler (a, b) {
        if (JSON.stringify(a) !== JSON.stringify(b)) {
          this.validDebouncer({
            handler: () => {
              if (a.$dirty) {
                if (a.$anyError) {
                  this.$set(this, 'validState', false) // red border
                  return
                } else if (this.highlightValid) {
                  this.$set(this, 'validState', true) // green border
                  return
                }
              }
              if (this.keyName in this.$store.state.session.formErrors) {
                this.$set(this, 'validState', false) // red border
                return
              }
              this.$set(this, 'validState', null) // no border
            },
            time: this.validDebouncerTime
          })
        }
      },
      deep: true
    }
  }
}
