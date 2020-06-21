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

export const renderSlots = (ctx, h) => {
  const $BButton = h(BButton, {
    ref: 'button-test',
    staticClass: 'input-group-text',
    props: {
      disabled: !ctx.canRunTest
    },
    attrs: {
      tabIndex: '-1' // ignore
    },
    on: {
      click: ctx.doRunTest
    }
  }, [
    // button label
    ctx.testLabel || ctx.$i18n.t('Test'),
    // show loading icon while testing
    ...((ctx.isTesting)
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
    ...((ctx.testResult !== null)
      ? [
        h(Icon, {
          staticClass: 'ml-3 mr-1',
          class: {
            'text-success': ctx.testResult,
            'text-danger': !ctx.testResult
          },
          props: {
            name: (ctx.testResult) ? 'check' : 'times'
          }
        })
      ]
      : []
    )
  ])

  return [
    h(BButtonGroup, {
      staticClass: 'pf-input-button-group'
    }, [
      // show test message when available
      ...((ctx.testResult !== null && ctx.testMessage)
        ? [
          h(BButton, {
            staticClass: 'mr-1',
            class: {
              'text-success': ctx.testResult,
              'text-danger': !ctx.testResult
            },
            props: {
              variant: 'light',
              disabled: true,
              tabindex: -1 // ignore
            }
          }, [ctx.testMessage])
        ]
        : []
      ),
      $BButton
    ])
  ]
}

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
      type: [Boolean, Function],
      default: false // don't show button unless test function is explicitly defined
    },
    testLabel: {
      type: String,
      default: null
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
    localDisabled () {
      return this.disabled || this.isTesting
    },
    localScopedSlots () {
      return (h) => {
        if (!this.test) {
          return this.$scopedSlots // defaults
        }
        // else
        return {
          ...this.$scopedSlots,
          append: ((this.$scopedSlots.append)
            ? props => [
                ...renderSlots(this, h),
                ...this.$scopedSlots.append(props)
              ]
            : () => renderSlots(this, h)
          )
        }
      }
    }
  },
  methods: {
    doRunTest (event) {
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
        else {
          this.$emit('fail', error)
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
