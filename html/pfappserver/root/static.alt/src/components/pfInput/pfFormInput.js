import {
  BButton,
  BFormGroup,
  BFormInput,
  BFormText,
  BInputGroup,
  BInputGroupAppend,
  BInputGroupPrepend,
  normalizeSlot
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
    //value: {},
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
    },
    mergedSlots () { // overloaded through inheritance
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
        state: this.localState,
        value: this.localValue
      },
      domProps: {},
      on: {
        ...this.$listeners, // forward $listeners
        input: this.onInput,
        change: this.onChange
      }
    })

    const $BInputGroup = h(BInputGroup, {
      scopedSlots: { // forward `prepend` and `append` scopedSlots to BInputGroup
        // prepend
        prepend: this.mergedSlots(h).prepend,
        // append
        append: props => [
        ...((this.mergedSlots(h).append) // slot(s) first
            ? [this.mergedSlots(h).append(props)]
            : []
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
            : []
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
          : {}
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
        : []
      )
    ])
  }
}
