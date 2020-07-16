<template>
  <b-form-row class="pf-field-type-match mx-0 mb-1 px-0" align-v="center" no-gutters
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" cols="1" align-self="start" class="pt-1 text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="4" align-self="start">

      <pf-form-chosen ref="type"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.type`"
        v-on="forwardListeners"
        label="text"
        track-by="value"
        :placeholder="typeLabel"
        :options="fields"
        :disabled="disabled"
        class="mr-1"
        collapse-object
      />

    </b-col>
    <b-col cols="6" align-self="start" class="pl-1">

      <pf-form-chosen ref="match" v-if="isComponentType([componentType.SELECTONE, componentType.SELECTMANY])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.match`"
        v-on="matchListeners"
        v-bind="matchAttrs"
        :multiple="isComponentType([componentType.SELECTMANY])"
        :close-on-select="isComponentType([componentType.SELECTONE])"
        :placeholder="matchPlaceholder"
        :disabled="disabled"
        :taggable="field.taggable"
        :tag-placeholder="field.tagPlaceholder || $t('Click to add new option')"
        label="text"
        track-by="value"
        collapse-object
        @tag="addUserTaggedOption"
      />

      <pf-form-datetime ref="match" v-else-if="isComponentType([componentType.DATETIME])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.match`"
        :config="{useCurrent: true, datetimeFormat: 'YYYY-MM-DD HH:mm:ss'}"
        :disabled="disabled"
        :moments="matchMoments"
        :placeholder="matchPlaceholder"
      />

      <pf-form-prefix-multiplier ref="match" v-else-if="isComponentType([componentType.PREFIXMULTIPLER])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.match`"
        :disabled="disabled"
        :placeholder="matchPlaceholder"
      />

      <pf-form-input ref="match" v-else-if="isComponentType([componentType.SUBSTRING])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.match`"
        :disabled="disabled"
        :placeholder="matchPlaceholder"
      />

      <pf-form-input ref="match" v-else-if="isComponentType([componentType.INTEGER])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.match`"
        :disabled="disabled"
        :placeholder="matchPlaceholder"
        type="number"
        step="1"
      />

    </b-col>
    <b-col v-if="$slots.append" cols="1" align-self="start" class="pt-1 text-center col-form-label">
      <slot name="append"></slot>
    </b-col>
  </b-form-row>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import Vue from 'vue'
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
  name: 'pf-field-type-match',
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
      default: () => { return this.default }
    },
    typeLabel: {
      type: String
    },
    matchLabel: {
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
      default: { type: null, match: null }, // default value
      userTaggedOption: null, // user defined option (w/ :tag="true")
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
    localMatch () {
      return this.inputValue.match
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
    options () {
      if (!this.localType) return []
      let options = Vue.observable([])
      if (this.userTaggedOption) options.push(this.userTaggedOption)
      if (this.fieldIndex >= 0) {
        const field = this.field
        for (const type of field.types) {
          if (type in fieldTypeValues) {
            // eslint-disable-next-line vue/no-async-in-computed-properties
            Promise.resolve(fieldTypeValues[type]()).then(_options => {
              options.push(..._options)
            })

          }
        }
      }
      return options
    },
    matchAttrs () {
      const { field: { attrs } = {}, options } = this
      return attrs || { options }
    },
    matchListeners () {
      const { field: { listeners } = {} } = this
      return listeners || {}
    },
    matchMoments () {
      const { field: { moments } = {} } = this
      return moments || []
    },
    matchPlaceholder () {
      const { field: { placeholder } = {} } = this
      return placeholder || null
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
          if (this.field.types.map(type => fieldTypeComponent[type]).includes(componentTypes[t])) return true
        }
      }
      return false
    },
    focus () {
      if (this.localType) {
        this.focusMatch()
      } else {
        this.focusType()
      }
    },
    focusType () {
      const { $refs: { type: { focus = () => {} } = {} } = {} } = this
      focus()
    },
    focusMatch () {
      const { $refs: { match: { focus = () => {} } = {} } = {} } = this
      focus()
    },
    addUserTaggedOption (userTaggedOption) {
      this.userTaggedOption = { name: userTaggedOption, value: userTaggedOption }
      this.$set(this.inputValue, 'match', userTaggedOption)
    }
  },
  watch: {
    localType: {
      handler: function () {
        if (!this.drag) { // don't focus when being dragged
          const field = this.field
          if (field && 'staticValue' in field) {
            this.$set(this.formStoreValue, 'match', field.staticValue) // set static value
          } else {
            this.$set(this.formStoreValue, 'match', null) // clear value
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
.pf-field-type-match {
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-right: 0px;
      padding-left: 0px;
    }
  }
}
</style>
