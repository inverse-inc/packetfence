<template>
  <b-row class="pf-field-type-value mx-0 mb-1 px-0" align-v="center" no-gutters>
    <b-col v-if="$slots.prepend" sm="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col :sm="3" align-self="start">

      <pf-form-chosen ref="prefix"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.prefix`"
        track-by="value"
        :placeholder="prefixLabel"
        :options="prefixes"
        :disabled="disabled"
        class="mr-1"
        collapse-object
      />

    </b-col>
    <b-col :sm="($slots.prepend && $slots.append) ? 3 : (($slots.prepend || $slots.append) ? 3 : 4)" align-self="start">

      <pf-form-chosen ref="type"
        v-bind="typeAttrs"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.type`"
        label="text"
        track-by="value"
        :placeholder="typeLabel"
        :options="fields"
        :disabled="disabled"
        class="mr-1"
        collapse-object
      />

    </b-col>
    <b-col sm="4" align-self="start" class="pl-1">

      <pf-form-chosen ref="value" v-if="isComponentType([componentType.SELECTONE, componentType.SELECTMANY])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.value`"
        v-on="valueListeners"
        v-bind="valueAttrs"
        :multiple="isComponentType([componentType.SELECTMANY])"
        :close-on-select="isComponentType([componentType.SELECTONE])"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
        label="text"
        track-by="value"
      />

      <pf-form-datetime ref="value" v-else-if="isComponentType([componentType.DATETIME])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.value`"
        :config="{useCurrent: true, datetimeFormat: 'YYYY-MM-DD HH:mm:ss'}"
        :moments="valueMoments"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      />

      <pf-form-prefix-multiplier ref="value" v-else-if="isComponentType([componentType.PREFIXMULTIPLIER])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.value`"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      />

      <pf-form-input ref="value" v-else-if="isComponentType([componentType.SUBSTRING])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.value`"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      />

      <pf-form-input ref="value" v-else-if="isComponentType([componentType.INTEGER])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.value`"
        type="number"
        step="1"
        :placeholder="valuePlaceholder"
        :disabled="disabled"
      />

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
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormInput,
    pfFormPrefixMultiplier
  },
  mixins: [
    pfMixinForm
  ],
  props: {
    value: {
      type: Object,
      default: () => { return { prefix: null, type: null, value: null } }
    },
    prefixLabel: {
      type: String
    },
    typeLabel: {
      type: String
    },
    typeAttrs: {
      type: Object,
      default: () => { return {} }
    },
    valueLabel: {
      type: String
    },
    fields: {
      type: Array,
      default: () => { return [] }
    },
    prefixes: {
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
      default: { prefix: null, type: null, value: null }, // default value
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
    localPrefix () {
      return this.inputValue.prefix
    },
    localType () {
      return this.inputValue.type
    },
    localValue () {
      return this.inputValue.value
    },
    field () {
      if (this.localType) return this.fields.find(field => field.value === this.localType)
      return {}
    },
    fieldIndex () {
      if (this.localType) {
        const index = this.fields.findIndex(field => field.value === this.localType)
        if (index >= 0) return index
      }
      return null
    },
    placeholder () {
      const { valueAttrs: { placeholder } = {} } = this
      return placeholder || this.valueLabel
    },
    options () {
      if (!this.localType) return []
      let options = []
      if (this.fieldIndex >= 0) {
        const { field: { types = [] } = {} } = this
        for (const type of types) {
          if (type in fieldTypeValues) options.push(...fieldTypeValues[type](this))
        }
      }
      return options
    },
    valueAttrs () {
      const { field: { attrs } = {}, options } = this
      return attrs || { options }
    },
    valueListeners () {
      const { field: { listeners } = {} } = this
      return listeners || {}
    },
    valueMoments () {
      const { field: { moments } = {} } = this
      return moments || []
    },
    valuePlaceholder () {
      const { field: { placeholder } = {} } = this
      return placeholder || null
    }
  },
  methods: {
    isComponentType (componentTypes) {
      const { field: { types = [] } = {}  } = this
      if (types.length > 0) {
        for (let t = 0; t < componentTypes.length; t++) {
          if (types.map(type => fieldTypeComponent[type]).includes(componentTypes[t])) return true
        }
      }
      if (componentTypes.includes(componentType.SUBSTRING)) return true // default to SUBSTRING
      return false
    },
    focus () {
      if (this.localPrefix) {
        if (this.localType) {
          this.focusValue()
        }
        else {
          this.focusType()
        }
      }
      else {
        if (this.localType) {
          this.focusValue()
        }
        else {
          this.focusPrefix()
        }
      }
    },
    focusPrefix () {
      const { $refs: { prefix: { focus = () => {} } = {} } = {} } = this
      focus()
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
    localPrefix: {
      handler: function () {
        if (!this.drag) { // don't focus when being dragged
          this.$nextTick(() => {
            this.focus()
          })
        }
      }
    },
    localType: {
      handler: function () {
        if (!this.drag) { // don't focus when being dragged
          const field = this.field
          if (field && 'staticValue' in field) {
            this.$set(this.formStoreValue, 'value', field.staticValue) // set static value
          } else {
            this.$set(this.formStoreValue, 'value', null) // clear value
            this.$nextTick(() => {
              this.focus()
            })
          }
        }
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
