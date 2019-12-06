<template>
  <b-row class="pf-field-type-value mx-0 mb-1 px-0" align-v="center" no-gutters
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" sm="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col :sm="($slots.prepend && $slots.append) ? 4 : (($slots.prepend || $slots.append) ? 5 : 6)" align-self="start">

      <pf-form-chosen
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.type`"
        v-model="localType"
        v-on="forwardListeners"
        ref="localType"
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

      <pf-form-chosen v-if="isComponentType([componentType.SELECTONE, componentType.SELECTMANY])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        v-model="localValue"
        v-on="listeners"
        v-bind="fieldAttrs"
        ref="localValue"
        label="name"
        track-by="value"
        :multiple="isComponentType([componentType.SELECTMANY])"
        :placeholder="placeholder"
        :disabled="disabled"
      ></pf-form-chosen>

      <pf-form-datetime v-else-if="isComponentType([componentType.DATETIME])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        v-model="localValue"
        ref="localValue"
        :config="{useCurrent: true, datetimeFormat: 'YYYY-MM-DD HH:mm:ss'}"
        :moments="moments"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      ></pf-form-datetime>

      <pf-form-prefix-multiplier v-else-if="isComponentType([componentType.PREFIXMULTIPLER])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        v-model="localValue"
        ref="localValue"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      ></pf-form-prefix-multiplier>

      <pf-form-input v-else-if="isComponentType([componentType.SUBSTRING])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        v-model="localValue"
        ref="localValue"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      ></pf-form-input>

      <pf-form-input v-else-if="isComponentType([componentType.INTEGER])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        v-model="localValue"
        ref="localValue"
        type="number"
        step="1"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      ></pf-form-input>

      <pf-form-input v-else-if="isComponentType([componentType.HIDDEN])"
        :formStoreName="formStoreName"
        :formNamespace="`${formNamespace}.value`"
        zzzv-model="localValue"
value="1"
        ref="localValue"
        type="text"
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
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'

export default {
  name: 'pf-field-type-value',
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormInput,
    pfFormPrefixMultiplier
  },
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
    },
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
        if (!this.value || Object.keys(this.value).length === 0) {
          // set default placeholder
          this.$emit('input', JSON.parse(JSON.stringify(this.default))) // keep dereferenced
          return this.default
        }
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    },
    localType: {
      get () {
        let type = (this.inputValue && typeof this.inputValue === 'object' && 'type' in this.inputValue) ? this.inputValue.type : this.default.type
        // check to see if `type` exists in our available fields
        if (type && !this.fields.find(field => field.value === type)) {
          // discard
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Action type "{type}" is not valid, ignoring.', { type: type }) })
          this.$set(this.inputValue, 'type', this.default.type) // clear `type`
          this.$set(this.inputValue, 'value', this.default.value) // clear `value`
          return null
        }
        return type
      },
      set (newType) {
        this.$set(this.inputValue, 'type', newType || this.default.type)
        this.$set(this.inputValue, 'value', this.default.value) // clear `value`
        this.emitValidations()
        this.$nextTick(() => { // wait until DOM updates with new type
          this.focusValue()
        })
      }
    },
    localValue: {
      get () {
        return (this.inputValue && 'value' in this.inputValue) ? this.inputValue.value : this.default.value
      },
      set (newValue) {
        this.$set(this.inputValue, 'value', newValue || this.default.value)
        this.emitValidations()
      }
    },
    field () {
      if (this.localType) return this.fields.find(field => field.value === this.localType)
      return null
    },
    fieldIndex () {
      if (this.localType) {
        const index = this.fields.findIndex(field => field.value === this.localType)
        if (index >= 0) return index
      }
      return null
    },
    placeholder () {
      const { fieldAttrs: { placeholder } = {} } = this
      return placeholder || this.valueLabel
    },
    options () {
      if (!this.localType) return []
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
      if (!this.localType) return []
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
      if (this.localType) {
        const index = this.fields.findIndex(field => field.value === this.localType)
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
      if (this.localType) {
        const index = this.fields.findIndex(field => field.value === this.localType)
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
      if (this.localType) {
        this.focusValue()
      } else {
        this.focusType()
      }
    },
    focusIndex (index = 0) {
      const refs = Object.values(this.$refs)
      if (index in refs && refs[index]) {
        const { $refs: { input: { $el } } = {} } = refs[index]
        if ($el && 'focus' in $el) $el.focus()
      }
    },
    focusType () {
      this.focusIndex(0)
    },
    focusValue () {
      this.focusIndex(1)
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
