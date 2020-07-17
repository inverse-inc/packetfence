<template>
  <b-form-row class="pf-field-attribute-operator-value mx-0 mb-1 px-0" align-v="center" no-gutters
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" sm="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col class="pl-0" sm="3" align-self="start">

      <pf-form-chosen ref="attribute"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.attribute`"
        label="text"
        track-by="value"
        :placeholder="attributeLabel"
        :options="fields"
        :disabled="disabled"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col class="pl-1" sm="3" align-self="start">

      <pf-form-chosen ref="operator" v-if="localAttribute"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.operator`"
        label="text"
        track-by="value"
        :placeholder="operatorLabel"
        :options="operators"
        :disabled="disabled"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col class="pl-1" sm="4" align-self="start">

      <pf-form-input ref="value" v-if="isComponentType([componentType.SUBSTRING])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.value`"
        :placeholder="valueLabel"
        :disabled="disabled"
      ></pf-form-input>

      <pf-form-datetime ref="value" v-else-if="isComponentType([componentType.TIME])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.value`"
        :config="{useCurrent: false, datetimeFormat: 'HH:mm'}"
        :disabled="disabled"
        placeholder="HH:mm"
      ></pf-form-datetime>

      <pf-form-chosen ref="value" v-else-if="isComponentType([componentType.SELECTONE, componentType.SELECTMANY])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.value`"
        v-bind="fieldAttrs"
        group-label="group"
        group-values="items"
        label="text"
        track-by="value"
        :multiple="isComponentType([componentType.SELECTMANY])"
        :close-on-select="isComponentType([componentType.SELECTONE])"
        :placeholder="valueLabel"
        :disabled="disabled"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col v-if="$slots.append" sm="1" align-self="start" class="px-0 text-center col-form-label">
      <slot name="append"></slot>
    </b-col>
  </b-form-row>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfMixinForm from '@/components/pfMixinForm'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
  pfFieldTypeOperators as fieldTypeOperators,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'

export default {
  name: 'pf-field-attribute-operator-value',
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormInput
  },
  mixins: [
    pfMixinForm
  ],
  props: {
    default: {
      type: Object,
      default: () => {
        return { attribute: null, operator: null, value: null }
      }
    },
    value: {
      type: Object,
      default: () => { return { attribute: null, operator: null, value: null } }
    },
    attributeLabel: {
      type: String
    },
    operatorLabel: {
      type: String
    },
    valueLabel: {
      type: String
    },
    fields: {
      type: Array,
      default: () => { return [] }
    },
    disabled: {
      type: Boolean,
      default: false
    },
    drag: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      componentType // @/globals/pfField
    }
  },
  computed: {
    inputValue: {
      get () {
        return { ...this.default, ...this.formStoreValue } // use FormStore
      },
      set (newValue = null) {
        this.formStoreValue = newValue // use FormStore
      }
    },
    localAttribute () {
      return this.inputValue.attribute
    },
    localOperator () {
      return this.inputValue.operator
    },
    localValue () {
      return this.inputValue.value
    },
    field () {
      if (this.localAttribute) return this.fields.find(field => field.value === this.localAttribute)
      return null
    },
    fieldIndex () {
      if (this.localAttribute) {
        const index = this.fields.findIndex(field => field.value === this.localAttribute)
        if (index >= 0) return index
      }
      return null
    },
    operators () {
      if (!this.localAttribute) return []
      let operators = []
      if (this.fieldIndex >= 0) {
        const field = this.field
        for (const type of field.types) {
          if (type in fieldTypeOperators) operators.push(...fieldTypeOperators[type])
        }
      }
      return operators
    },
    options () {
      if (!this.localAttribute) return []
      let options = []
      if (this.fieldIndex >= 0) {
        const field = this.field
        for (const type of field.types) {
          if (type in fieldTypeValues) options.push(...fieldTypeValues[type](this))
        }
      }
      return options
    },
    fieldAttrs () {
      const { field: { attrs } = {} } = this
      return attrs || { options: this.options }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    isComponentType (componentTypes) {
      if (this.field) {
        for (let t = 0; t < componentTypes.length; t++) {
          let componentType = componentTypes[t]
          if (this.field.types.map(fieldType => fieldTypeComponent[fieldType]).includes(componentType)) return true
        }
      }
      return false
    },
    focus () {
      if (this.localAttribute) {
        if (this.localOperator) {
          this.focusValue()
        } else {
          this.focusOperator()
        }
      } else {
        this.focusAttribute()
      }
    },
    focusAttribute () {
      const { $refs: { attribute: { focus = () => {} } = {} } = {} } = this
      focus()
    },
    focusOperator () {
      const { $refs: { operator: { focus = () => {} } = {} } = {} } = this
      focus()
    },
    focusValue () {
      const { $refs: { value: { focus = () => {} } = {} } = {} } = this
      focus()
    }
  },
  watch: {
    localAttribute: {
      handler: function (a) {
        if (!this.drag && a) { // don't focus when being dragged
          this.$set(this.formStoreValue, 'operator', null) // clear operator
          this.$set(this.formStoreValue, 'value', null) // clear value
          this.$nextTick(() => {
            this.focusOperator()
          })
        }
      }
    },
    localOperator: {
      handler: function (a) {
        if (!this.drag && a) { // don't focus when being dragged
          this.$set(this.formStoreValue, 'value', null) // clear value
          this.$nextTick(() => {
            this.focusValue()
          })
        }
      }
    }
  }
}
</script>

<style lang="scss">
.pf-field-attribute-operator-value {
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-right: 0px;
      padding-left: 0px;
    }
  }
}
</style>
