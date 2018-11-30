<template>
  <b-form-row class="pf-field-test mx-0 mb-1 px-0 col-12" align-v="center"
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" cols="1" align-self="start" class="pt-1 text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="4" align-self="start">

      <pf-form-chosen
        v-model="localType"
        ref="localType"
        label="text"
        track-by="value"
        :placeholder="typeLabel"
        :options="fields"
        :validation="typeVuelidateModel"
        :invalid-feedback="typeInvalidFeedback"
        class="mr-1"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col cols="6" align-self="start" class="pl-1">

      <!-- Types: ADMINROLE, ROLE, ROLE_BY_NAME, TENANT, DURATION -->
      <pf-form-chosen v-if="
          isFieldType(adminroleValueType) ||
          isFieldType(roleValueType) ||
          isFieldType(roleByNameValueType) ||
          isFieldType(tenantValueType) ||
          isFieldType(durationValueType)
        "
        v-model="localValue"
        ref="localValue"
        label="name"
        track-by="value"
        :placeholder="valueLabel"
        :options="options"
        :validation="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
        class="ml-1"
        collapse-object
      ></pf-form-chosen>

      <!-- Type: DATETIME -->
      <pf-form-datetime v-if="isFieldType(datetimeValueType)"
        v-model="localValue"
        ref="localValue"
        :config="{useCurrent: true, format: 'YYYY-MM-DD HH:mm:ss'}"
        :moments="moments"
        :validation="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
        class="ml-1"
      ></pf-form-datetime>

      <!-- Type: PREFIXMULTIPLER -->
      <pf-form-prefix-multiplier v-if="isFieldType(prefixmultiplerValueType)"
        v-model="localValue"
        ref="localValue"
        :validation="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
        class="ml-1"
      ></pf-form-prefix-multiplier>

    </b-col>
    <b-col v-if="$slots.append" cols="1" align-self="start" class="pt-1 text-center col-form-label">
      <slot name="append"></slot>
    </b-col>
  </b-form-row>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import pfMixinValidation from '@/components/pfMixinValidation'
import {
  pfFieldType as fieldType,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import { required } from 'vuelidate/lib/validators'

export default {
  name: 'pf-field-test',
  mixins: [
    pfMixinValidation
  ],
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormPrefixMultiplier
  },
  props: {
    value: {
      type: Object,
      default: () => { return { type: null, value: null } }
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
    validation: {
      type: Object,
      default: () => { return {} }
    }
  },
  data () {
    return {
      valuePlaceHolder:         { type: null, value: null }, // default value
      /* Generic field types */
      noValueType:              fieldType.NONE,
      integerValueType:         fieldType.INTEGER,
      substringValueType:       fieldType.SUBSTRING,
      /* Custom element field types */
      datetimeValueType:        fieldType.DATETIME,
      prefixmultiplerValueType: fieldType.PREFIXMULTIPLIER,
      durationValueType:        fieldType.DURATION,
      /* Promise based field types */
      adminroleValueType:       fieldType.ADMINROLE,
      roleValueType:            fieldType.ROLE,
      roleByNameValueType:      fieldType.ROLE_BY_NAME,
      tenantValueType:          fieldType.TENANT
    }
  },
  computed: {
    inputValue: {
      get () {
        if (!this.value || Object.keys(this.value).length === 0) {
          // set default placeholder
          this.$emit('input', this.valuePlaceHolder)
          return this.valuePlaceHolder
        }
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    },
    localType: {
      get () {
        let type = (this.inputValue && 'type' in this.inputValue) ? this.inputValue.type : null
        // check to see if `type` exists in our available fields
        if (type && !this.fields.find(field => field.value === type)) {
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Action type "{type}" is not valid, ignoring...', { type: type }) })
          this.$set(this.inputValue, 'type', null) // clear `type`
          this.$set(this.inputValue, 'value', null) // clear `value`
          return null
        }
        return type
      },
      set (newType) {
        this.$set(this.inputValue, 'type', newType || null) // type or null
        this.emitExternalValidations()
      }
    },
    localValue: {
      get () {
        return (this.inputValue && 'value' in this.inputValue) ? this.inputValue.value : null
      },
      set (newValue) {
        this.$set(this.inputValue, 'value', newValue || null) // value or null
        this.emitExternalValidations()
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
    options () {
      if (!this.localType) return []
      let options = []
      if (this.fieldIndex >= 0) {
        const field = this.field
        for (const type of field.types) {
          if (fieldTypeValues[type]) options.push(...fieldTypeValues[type](this.$store))
        }
      }
      return options
    },
    moments () {
      if ('moments' in this.field) return this.field.moments
      return []
    },
    typeVuelidateModel () {
      return this.getVuelidateModel('type')
    },
    typeInvalidFeedback () {
      return this.getInvalidFeedback('type')
    },
    valueVuelidateModel () {
      return this.getVuelidateModel('value')
    },
    valueInvalidFeedback () {
      return this.getInvalidFeedback('value')
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    isFieldType (type) {
      if (!this.localType) return false
      const index = this.fields.findIndex(field => field.value === this.localType)
      if (index >= 0) {
        const field = this.fields[index]
        if (field.types.includes(type)) return true
      }
      return false
    },
    getVuelidateModel (key = null) {
      let model = {}
      if (this.validation && Object.keys(this.validation).length > 0) {
        if (key in this.validation) model = this.validation[key]
        if ('$each' in this.validation && key in this.validation.$each) model = this.validation.$each[key]
      }
      return model
    },
    getInvalidFeedback (key = null) {
      let feedback = []
      const validation = this.getVuelidateModel(key)
      if (validation !== {} && key in validation) {
        Object.entries(validation[key].$params).forEach(([k, v]) => {
          if (validation[key][k] === false) feedback.push(k.trim())
        })
      }
      return feedback.join('<br/>')
    },
    getExternalValidations () {
      const field = this.field
      if (field) {
        if ('validators' in field) { // has vuelidate validations
          let validations = {}
          if ('type' in field.validators) validations.type = field.validators.type
          if ('value' in field.validators) validations.value = field.validators.value
          return validations
        }
      }
      return { type: { [this.$i18n.t('Type required.')]: required } }
    },
    emitExternalValidations () {
      this.$emit('validations', this.getExternalValidations())
    }
  },
  mounted () {
    this.emitExternalValidations()
  }
}
</script>

<style lang="scss">
.pf-field-test {
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-left: 0px;
      padding-right: 0px;
    }
  }
}
</style>
