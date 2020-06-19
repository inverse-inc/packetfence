import {
  BButton,
  BFormGroup,
  BFormInput,
  BFormText,
  BInputGroup,
  BInputGroupAppend,
  BInputGroupPrepend
} from 'bootstrap-vue'
import Icon from 'vue-awesome/components/Icon'

import mixinSass from './mixin.scss' // mixin scoped sass
import mixinFormModel from '@/components/_mixins/formModel'

// @vue/component
export default {
  name: 'pf-form-input',
  mixins: [
    mixinFormModel, // uses v-model
    mixinSass
  ],
  props: {
    // value defined in formModel mixin
    //value: {/* noop */},
    columnLabel: {
      type: String
    },
    labelCols: {
      type: [String, Number],
      default: 3
    },
    text: {
      type: String
    },
    disabled: {
      type: Boolean
    },
    readonly: {
      type: Boolean
    }
  },
  computed: {
    mergeDisabled () { // overloaded through inheritance
      return this.disabled
    },
    mergeSlots () { // overloaded through inheritance
      return (h) => {
        return this.$scopedSlots // defaults
      }
    }
  },
  methods: {
    focus () {
      this.$refs.input.focus()
    },
    onInput (event) {
      this.$emit('input', event) // bubble up
      this.localValue = event
    },
    onChange (event) {
      this.$emit('change', event) // bubble up
      this.localValue = event
    }
  },
  render (h) { // https://vuejs.org/v2/guide/render-function.html

    const $BFormInput = h(BFormInput, {
      ref: 'input',
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
        disabled: this.mergeDisabled,
        state: this.localState,
        value: this.localValue
      },
      domProps: {/* noop */},
      on: {
        ...this.$listeners, // forward $listeners
        input: this.onInput,
        change: this.onChange
      }
    })

    const $BInputGroup = h(BInputGroup, {
      class: { // append state class to input-group
        'is-valid': this.localState === true,
        'is-invalid': this.localState === false
      },
      scopedSlots: { // forward `prepend` and `append` scopedSlots to BInputGroup
        // prepend
        prepend: this.mergeSlots(h).prepend,
        // append
        append: props => [
        ...((this.mergeSlots(h).append) // slot(s) first
            ? [this.mergeSlots(h).append(props)]
            : [/* noop */]
          ),
          ...((this.disabled || this.readonly) // icon last
            ? [
              h(BButton, {
                staticClass: 'input-group-text',
                props: {
                  disabled: true,
                  tabIndex: -1 // ignore
                }
              }, [
                h(Icon, {
                  props: {
                    name: 'lock'
                  }
                })
              ])
            ]
            : [/* noop */]
          )
        ]
      }
    }, [$BFormInput])

    return h(BFormGroup, {
      staticClass: 'pf-form-input',
      class: {
        'mb-0': !this.columnLabel
      },
      props: {
        state: this.localState,
        invalidFeedback: this.localInvalidFeedback,
        ...((this.columnLabel)
          ? {
              labelCols: this.labelCols,
              label: this.columnLabel
          }
          : {/* noop */}
        )
      }
    }, [
      $BInputGroup,
      ...((this.text)
        ? [h(BFormText, {
          domProps: {
            innerHTML: this.text
          }
        })]
        : [/* noop */]
      )
    ])
  }
}
