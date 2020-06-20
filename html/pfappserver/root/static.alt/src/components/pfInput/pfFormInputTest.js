import {
  BButton,
  BButtonGroup
} from 'bootstrap-vue'
import * as Icon from 'vue-awesome'

import pfFormInput from './pfFormInput'
import mixinScss from './mixin.scss' // mixin scoped scss
import {
  mixinFormHandlers,
  mixinFormModel,
  mixinFormState
} from '@/components/_mixins/'

// @vue/component
export default {
  name: 'pf-form-input-test',
  extends: pfFormInput,
  mixins: [
    mixinFormHandlers,
    mixinFormModel, // uses v-model
    mixinFormState,
    mixinScss
  ],
  props: {
    test: {
      type: Function
    }
  },
  data () {
    return {
      testResult: null,
      testMessage: null,
      isTesting: false
    }
  },
  computed: {
    canRunTest () {
      return !this.disabled && this.localValue && !this.isTesting && this.localState !== false
    },
    mergeDisabled () {
      return this.disabled || this.isTesting
    },
    mergeSlots () {
      return (h) => {

        const $BButton = h(BButton, {
          ref: 'button-test',
          staticClass: 'input-group-text',
          props: {
            disabled: !this.canRunTest,
            tabIndex: -1 // ignore
          },
          on: {
            click: this.onRunTest
          }
        }, [
          // button label
          this.$i18n.t('Test'),
          // show loading icon while testing
          ...((this.isTesting)
            ? [h(Icon, {
              staticClass: 'ml-3 mr-1',
              props: {
                name: 'circle-notch',
                spin: true
              }
            })]
            : []
          ),
          // show test result icon
          ...((this.testResult !== null)
            ? [
              h(Icon, {
                staticClass: 'ml-3 mr-1',
                class: {
                  'text-success': this.testResult,
                  'text-danger': !this.testResult
                },
                props: {
                  name: (this.testResult) ? 'check' : 'times'
                }
              })
            ]
            : []
          )
        ])

        const $BButtonGroup = h(BButtonGroup, {
          staticClass: 'pf-input-button-group'
        }, [
          // show test message when available
          ...((this.testResult !== null && this.testMessage)
            ? [
              h(BButton, {
                staticClass: 'mr-1',
                class: {
                  'text-success': this.testResult,
                  'text-danger': !this.testResult
                },
                props: {
                  variant: 'light',
                  disabled: true,
                  tabindex: -1 // ignore
                }
              }, [this.testMessage])
            ]
            : []
          ),
          $BButton
        ])

        return {
          ...this.$scopedSlots,
          append: ((this.$scopedSlots.append)
            ? props => [
                this.$scopedSlots.append(props),
                $BButtonGroup
              ]
            : () => $BButtonGroup
          )
        }
      }
    }
  },
  methods: {
    onRunTest (event) {
      this.isTesting = true
      this.testResult = null
      Promise.resolve(this.test()).then(response => {
        this.testResult = true
        this.testMessage = null
        this.$emit('pass', response)
        this.isTesting = false
      }).catch(error => {
        this.testResult = false
        this.testMessage = this.$i18n.t('Test failed with unknown error.')
        const { response: { data } = {} } = error
        if (data) {
          const { message } = data
          if (message) this.testMessage = message
          this.$emit('fail', data)
        }
        this.isTesting = false
      })
    }
  },
  watch: {
    localValue () { // clear the test result on change
      this.testMessage = null
      this.testResult = null
    }
  }
}
