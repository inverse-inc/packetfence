<template>
  <b-form-row class="pf-field-action mx-0 mb-1 px-0" align-v="center"
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" cols="1" align-self="start" class="pt-1 text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="4" align-self="start">

      <pf-form-chosen
        v-model="localType"
        v-on="forwardListeners"
        ref="localType"
        label="text"
        track-by="value"
        :placeholder="typeLabel"
        :options="fields"
        :vuelidate="typeVuelidateModel"
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
        :vuelidate="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
        collapse-object
      ></pf-form-chosen>

      <!-- Type: DATETIME -->
      <pf-form-datetime v-if="isFieldType(datetimeValueType)"
        v-model="localValue"
        ref="localValue"
        :config="{useCurrent: true, format: 'YYYY-MM-DD HH:mm:ss'}"
        :moments="moments"
        :vuelidate="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
      ></pf-form-datetime>

      <!-- Type: PREFIXMULTIPLER -->
      <pf-form-prefix-multiplier v-if="isFieldType(prefixmultiplerValueType)"
        v-model="localValue"
        ref="localValue"
        :vuelidate="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
      ></pf-form-prefix-multiplier>

      <!-- Type: SUBSTRING -->
      <pf-form-input v-if="isFieldType(substringValueType)"
        v-model="localValue"
        ref="localValue"
        :vuelidate="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
      ></pf-form-input>

      <!-- Type: INTEGER -->
      <pf-form-input v-if="isFieldType(integerValueType)"
        v-model="localValue"
        ref="localValue"
        type="number"
        step="1"
        :vuelidate="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
      ></pf-form-input>

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
import pfFormInput from '@/components/pfFormInput'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import {
  pfFieldType as fieldType,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import { required } from 'vuelidate/lib/validators'

export default {
  name: 'pf-field-action',
  components: {
    pfFormChosen,
    pfFormDatetime,
    pfFormInput,
    pfFormPrefixMultiplier
  },
  props: {
    value: {
      type: Object,
      default: () => { return this.default }
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
    vuelidate: {
      type: Object,
      default: () => { return {} }
    }
  },
  data () {
    return {
      default:                  { type: null, value: null }, // default value
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
        let type = (this.inputValue && 'type' in this.inputValue) ? this.inputValue.type : this.default.type
        // check to see if `type` exists in our available fields
        if (type && !this.fields.find(field => field.value === type)) {
          // discard
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Action type "{type}" is not valid, ignoring...', { type: type }) })
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
      const { vuelidate: { [key]: model } } = this
      return model || {}
    },
    getInvalidFeedback (key = null) {
      let feedback = []
      const vuelidate = this.getVuelidateModel(key)
      if (vuelidate !== {} && key in vuelidate) {
        Object.entries(vuelidate[key].$params).forEach(([k, v]) => {
          if (vuelidate[key][k] === false) feedback.push(k.trim())
        })
      }
      return feedback.join('<br/>')
    },
    buildLocalValidations () {
      const { field } = this
      if (field) {
        const { validators } = field
        if (validators) {
          return validators
        }
      }
      return { type: { [this.$i18n.t('Type required.')]: required } }
    },
    emitValidations () {
      this.$emit('validations', this.buildLocalValidations())
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
      if (index in refs) {
        const { $refs: { input: { $el } } } = refs[index]
        if ($el && 'focus' in $el) $el.focus()
      }
    },
    focusType () {
      this.focusIndex(0)
    },
    focusValue () {
      this.focusIndex(1)
    }
  },
  created () {
    this.emitValidations()
    this.$store.dispatch('config/getAdminRoles') // roles for actions > set_access_level
    this.$store.dispatch('config/getRoles') // roles for actions > set_role
    this.$store.dispatch('config/getTenants') // tenants for actions > set_tenant_id
  }
}
</script>

<style lang="scss">
.pf-field-action {
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-left: 0px;
      padding-right: 0px;
    }
  }
}
</style>
