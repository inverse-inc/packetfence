<template>
  <b-row class="pf-field-type-value mx-0 mb-1 px-0" align-v="center" no-gutters
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" sm="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col :sm="($slots.prepend && $slots.append) ? 4 : (($slots.prepend || $slots.append) ? 5 : 6)" align-self="start">

      <pf-form-chosen ref="type"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.type`"
        v-on="forwardListeners"
        label="text"
        track-by="value"
        :placeholder="typeLabel"
        :options="fields"
        :disabled="disabled"
        class="mr-1"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col sm="6" align-self="start" class="pl-1">

      <pf-form-chosen ref="value" v-if="isComponentType([componentType.SELECTONE, componentType.SELECTMANY])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        v-on="listeners"
        v-bind="fieldAttrs"
        label="name"
        track-by="value"
        :multiple="isComponentType([componentType.SELECTMANY])"
        :placeholder="placeholder"
        :disabled="disabled"
      ></pf-form-chosen>

      <pf-form-datetime ref="value" v-else-if="isComponentType([componentType.DATETIME])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        :config="{useCurrent: true, datetimeFormat: 'YYYY-MM-DD HH:mm:ss'}"
        :moments="moments"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      ></pf-form-datetime>

      <pf-form-prefix-multiplier ref="value" v-else-if="isComponentType([componentType.PREFIXMULTIPLER])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      ></pf-form-prefix-multiplier>

      <pf-form-input ref="value" v-else-if="isComponentType([componentType.SUBSTRING])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      ></pf-form-input>

      <pf-form-input ref="value" v-else-if="isComponentType([componentType.INTEGER])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        type="number"
        step="1"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      ></pf-form-input>

    </b-col>
    <b-col v-if="$slots.append" sm="1" align-self="start" class="text-center col-form-label">
      <slot name="append"></slot>
    </b-col>
  </b-row>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import pfMixinForm from '@/components/pfMixinForm'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'

export default {
  name: 'pf-field-type-value',
  mixins: [
    pfMixinForm
  ],
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormInput,
    pfFormPrefixMultiplier
  },
  props: {
    value: {
      type: Object,
      default: () => {}
    },
    typeLabel: {
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
      default: { type: null, value: null }, // default value
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
    localType () {
     return this.inputValue.type
    },
    localValue () {
      return this.inputValue.value
    },
    field () {
      if (this.inputValue.type) return this.fields.find(field => field.value === this.inputValue.type)
      return null
    },
    fieldIndex () {
      if (this.inputValue.type) {
        const index = this.fields.findIndex(field => field.value === this.inputValue.type)
        if (index >= 0) return index
      }
      return null
    },
    placeholder () {
      const { fieldAttrs: { placeholder } = {} } = this
      return placeholder || this.valueLabel
    },
    options () {
      if (!this.inputValue.type) return []
      let options = []
      if (this.fieldIndex >= 0) {
        const field = this.field
        for (const type of field.types) {
          if (type in fieldTypeValues) options.push(...fieldTypeValues[type](this))
        }
      }
      return options
    },
    optionsSearchFunction () {
      if (this.field) {
        return this.field.optionsSearchFunction
      }
    },
    listeners () {
      if (!this.inputValue.type) return []
      let listeners = {}
      if (this.fieldIndex >= 0) {
        if (this.field.listeners) {
          listeners = this.field.listeners
        }
      }
      return listeners
    },
    moments () {
      if ('moments' in this.field) return this.field.moments
      return []
    },
    fieldAttrs () {
      const { field: { attrs } = {} } = this
      return attrs || { options: this.options }
    },
    valuePlaceholder () {
      return this.getPlaceholder()
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    isComponentType (componentTypes) {
      if (this.inputValue.type) {
        const index = this.fields.findIndex(field => field.value === this.inputValue.type)
        if (index >= 0) {
          const field = this.fields[index]
          for (let t = 0; t < componentTypes.length; t++) {
            if (field.types.map(type => fieldTypeComponent[type]).includes(componentTypes[t])) return true
          }
        }
      }
      return false
    },
    getPlaceholder () {
      if (this.inputValue.type) {
        const index = this.fields.findIndex(field => field.value === this.inputValue.type)
        if (index >= 0) {
          const field = this.fields[index]
          if ('placeholder' in field) {
            return field.placeholder
          }
        }
      }
      return null
    },
    focus () {
      if (this.inputValue.type) {
        this.focusValue()
      } else {
        this.focusType()
      }
    },
    focusType () {
      const { $refs: { type: { focus = () => {} } = {} } = {} } = this
      focus()
    },
    focusValue () {
      const { $refs: { value: { focus = () => {} } = {} } = {} } = this
      focus()
    }
  },
  watch: {
    localType: {
      handler: function (a, b) {
        this.$nextTick(() => {
          const field = this.field
          if ('staticValue' in field) {
            this.$set(this.formStoreValue, 'value', field.staticValue) // set static value
          } else {
            this.$set(this.formStoreValue, 'value', null) // clear value
            if (!this.drag) { // don't focus when being dragged
              this.focus()
            }
          }
        })
      }
    }
  }
}
</script>

<style lang="scss">
.pf-field-type-value {
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-right: 0px;
      padding-left: 0px;
    }
  }
}
</style>
