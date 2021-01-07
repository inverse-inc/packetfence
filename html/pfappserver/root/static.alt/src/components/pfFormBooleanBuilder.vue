<template>
  <div>
    <pf-form-range-toggle
      :value="advancedMode" @input="advancedMode = $event"
      :values="{checked: true, unchecked: false}"
      :rightLabels="{checked: $t('Advanced Mode'), unchecked: $t('Basic Mode')}"
      :disabled="disabled"
      class="text-nowrap mb-3 small"
    />

    <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputStateIfInvalidFeedback"
      class="pf-form-boolean-builder" :class="{ 'mb-0': !columnLabel }">
      <template v-slot:invalid-feedback>
        {{ invalidFeedback }}
      </template>
      <b-input-group class="pf-form-boolean-builder-input-group p-1">

        <!-- Advanced Mode -->
        <pf-form-textarea v-if="advancedMode" ref="advancedCondition"
          v-model="advancedCondition"
          :disabled="disabled"
          :state="(advancedError) ? false : null"
          :invalidFeedback="advancedError"
          class="w-100" rows="3" max-rows="10"
        />

        <!-- Basic Mode -->
        <pf-form-boolean v-else
          :form-store-name="formStoreName" :form-namespace="formNamespace" :disabled="disabled"
        >
          <template v-slot:op="{ formStoreName, formNamespace, disabled }">
            <pf-form-chosen
              :form-store-name="formStoreName"
              :form-namespace="formNamespace + '.op'"
              :options="valuesOperators"
              :allow-empty="false"
              :disabled="disabled"
              class="m-1"
            />
          </template>
          <template v-slot:value="{ formStoreName, formNamespace, disabled }">
            <div class="pf-form-boolean-builder-value">
              <pf-form-chosen v-show="showField(formNamespace)"
                :form-store-name="formStoreName"
                :form-namespace="formNamespace + '.field'"
                :options="fieldOperators"
                :options-limit="fieldOperators.length"
                :allow-empty="false"
                :disabled="disabled"
                class="m-1"
              />
              <pf-form-chosen
                :form-store-name="formStoreName"
                :form-namespace="formNamespace + '.op'"
                :options="valueOperators"
                :allow-empty="false"
                :disabled="disabled"
                class="m-1"
              />
              <!-- `value` w/ options -->
              <pf-form-chosen v-show="showValue(formNamespace) && valueOptions(formNamespace).length > 0"
                :form-store-name="formStoreName"
                :form-namespace="formNamespace + '.value'"
                :options="valueOptions(formNamespace)"
                :taggable="true"
                :allow-empty="false"
                :disabled="disabled"
                class="m-1"
              />
              <!-- `value` w/o options -->
              <pf-form-input v-show="showValue(formNamespace) && valueOptions(formNamespace).length === 0"
                :form-store-name="formStoreName"
                :form-namespace="formNamespace + '.value'"
                :disabled="disabled"
                class="m-1"
              />
            </div>
          </template>
        </pf-form-boolean>

      </b-input-group>
    </b-form-group>
  </div>
</template>

<script>
import pfFormBoolean from '@/components/pfFormBoolean'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfMixinForm from '@/components/pfMixinForm'
import { createDebouncer } from 'promised-debounce'

const highlightError = (error, offset, length = 15) => {
  let start = Math.max(0, offset - Math.floor(length / 2) - 1)
  let end = Math.min(start + length, error.length)
  start -= Math.max(0, length + start - end)
  let chr = ''
  let string = ''
  for (let i = start; i < end; i++) {
    if (i >= 0 && i < error.length) {
      chr = (error[i] === ' ') ? '\u00a0' : error[i]
      string += (i === offset)
        ? `<span class="bg-danger text-white">${chr}</span>`
        : error[i]
    }
  }
  return `${(start > 0) ? '...' : ''}${string}${(end < error.length) ? '...' : ''}`
}

export default {
  name: 'pf-form-boolean-builder',
  components: {
    pfFormBoolean,
    pfFormChosen,
    pfFormInput,
    pfFormRangeToggle,
    pfFormTextarea
  },
  mixins: [
    pfMixinForm
  ],
  props: {
    fieldOperators: {
      type: Array,
      default: () => { return [] }
    },
    valueOperators: {
      type: Array,
      default: () => { return [] }
    },
    valuesOperators: {
      type: Array,
      default: () => { return [] }
    },
    disabled: {
      type: Boolean,
      default: false
    },
    columnLabel: {
      type: String
    },
    labelCols: {
      type: [String, Number],
      default: 3
    }
  },
  data () {
    return {
      advancedMode: false,
      advancedCondition: null,
      advancedError: null
    }
  },
  computed: {
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    basicCondition: {
      get () {
        return this.form[this.formNamespace]
      },
      set (newValue) {
        this.$set(this.form, this.formNamespace, newValue)
      }
    },
    requiresFieldsAssociated () {
      return this.valueOperators.reduce((associated, item) => {
        const { value, requires } = item
        associated[value] = requires
        return associated
      }, {})
    },
    showField () {
      return (namespace) => {
        const { vModel: { [namespace]: { op } = {} } = {} } = this
        const { requiresFieldsAssociated: { [op]: requires = [] } = {} } = this
        return (!op || requires.includes('field'))
      }
    },
    showValue () {
      return (namespace) => {
        const { vModel: { [namespace]: { op } = {} } = {} } = this
        const { requiresFieldsAssociated: { [op]: requires = [] } = {} } = this
        return (!op || requires.includes('value'))
      }
    }
  },
  methods: {
    valueOptions (namespace) {
      const { vModel: { [namespace]: { field } = {} } = {} } = this
      if (field) {
        const { options = [] } = this.fieldOperators.find(fieldOperator => {
          const { text, options = [] } = fieldOperator
          if (text === field) {
            return options
          }
        }) || {}
        return options
      }
      return []
    }
  },
  watch: {
    advancedMode: {
      handler: function (advancedMode) {
        if (advancedMode) {
          this.$nextTick(() => {
            const { $refs: { advancedCondition: { focus = () => {}, select = () => {} } = {} } = {} } = this
            focus()
            select()
          })
        }
      }
    },
    advancedCondition: {
      handler: function (string) {
        if (string && this.advancedMode) {
          if (!this.$debouncer) {
            this.$debouncer = createDebouncer()
          }
          this.$debouncer({
            handler: () => {
              this.$store.dispatch('config/parseCondition', string).then(condition => {
                this.basicCondition = condition
                this.advancedError = null
              }).catch(err => {
                const { response: { data: { errors: { 0: { highlighted_error, offset } = {} } = {} } = {} } = {} } = err
                const { 0: error = '' } = highlighted_error.split('\n')
                if (error) {
                  this.advancedError = `${error}: <code class="text-secondary font-weight-bold">\u00a0${highlightError(string, offset)}\u00a0</code>`
                } else {
                  this.advancedError = null
                }
              })
            },
            time: 1000 // 1 second
          })
        }
      }
    },
    basicCondition: {
      handler: function (json) {
        if (json && !this.advancedMode) {
          if (!this.$debouncer) {
            this.$debouncer = createDebouncer()
          }
          this.$debouncer({
            handler: () => {
              this.$store.dispatch('config/stringifyCondition', json).then(condition => {
                this.advancedCondition = condition
                this.advancedError = null
              })
            },
            time: 1000 // 1 second
          })
        }
      },
      deep: true
    }
  }
}
</script>

<style lang="scss">
.pf-form-boolean-builder {
  .pf-form-boolean-builder-input-group {
    border: 1px solid transparent;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;
  }
  &.is-focus {
    > [role="group"] > .pf-form-boolean-builder-input-group,
    > .form-row > [role="group"] > .pf-form-boolean-builder-input-group {
      border-color: $input-focus-border-color;
      box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
    }
  }
  &.is-invalid {
    > [role="group"] > .pf-form-boolean-builder-input-group,
    > .form-row > [role="group"] > .pf-form-boolean-builder-input-group {
      border-color: $form-feedback-invalid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
    }
  }
  .pf-form-boolean-builder-value {
    display: flex;
    flex-wrap: wrap;
    justify-content: flex-start;
    & > * {
      align-items: stretch;
    }
  }
}
</style>
