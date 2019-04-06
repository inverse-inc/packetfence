<template>
  <b-form-row class="pf-field-type-match mx-0 mb-1 px-0" align-v="center"
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
        :disabled="disabled"
        class="mr-1"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col cols="6" align-self="start" class="pl-1">

      <!-- Types: CONNECTION_SUB_TYPE, CONNECTION_TYPE, DURATION, ADMINROLE, REALM, ROLE, ROLE_BY_NAME, TENANT, REALM, SWITCH, SWITCH_GROUP, TIME_BALANCE -->
      <pf-form-chosen v-if="
          isFieldType(connectionSubTypeValueType) ||
          isFieldType(connectionTypeValueType) ||
          isFieldType(durationValueType) ||
          isFieldType(adminroleValueType) ||
          isFieldType(realmValueType) ||
          isFieldType(roleValueType) ||
          isFieldType(roleByNameValueType) ||
          isFieldType(tenantValueType) ||
          isFieldType(switchValueType) ||
          isFieldType(switchGroupValueType) ||
          isFieldType(timeBalanceValueType)
        "
        v-model="localMatch"
        ref="localMatch"
        label="name"
        track-by="value"
        :placeholder="matchLabel"
        :options="options"
        :vuelidate="matchVuelidateModel"
        :invalid-feedback="matchInvalidFeedback"
        :disabled="disabled"
        collapse-object
      ></pf-form-chosen>

      <!-- Type: DATETIME -->
      <pf-form-datetime v-else-if="isFieldType(datetimeValueType)"
        v-model="localMatch"
        ref="localMatch"
        :config="{useCurrent: true, format: 'YYYY-MM-DD HH:mm:ss'}"
        :moments="moments"
        :vuelidate="matchVuelidateModel"
        :invalid-feedback="matchInvalidFeedback"
        :disabled="disabled"
      ></pf-form-datetime>

      <!-- Type: PREFIXMULTIPLER -->
      <pf-form-prefix-multiplier v-else-if="isFieldType(prefixmultiplerValueType)"
        v-model="localMatch"
        ref="localMatch"
        :vuelidate="matchVuelidateModel"
        :invalid-feedback="matchInvalidFeedback"
        :disabled="disabled"
      ></pf-form-prefix-multiplier>

      <!-- Type: SUBSTRING -->
      <pf-form-input v-else-if="isFieldType(substringValueType)"
        v-model="localMatch"
        ref="localMatch"
        :vuelidate="matchVuelidateModel"
        :invalid-feedback="matchInvalidFeedback"
        :disabled="disabled"
      ></pf-form-input>

      <!-- Type: INTEGER -->
      <pf-form-input v-else-if="isFieldType(integerValueType)"
        v-model="localMatch"
        ref="localMatch"
        type="number"
        step="1"
        :vuelidate="matchVuelidateModel"
        :invalid-feedback="matchInvalidFeedback"
        :disabled="disabled"
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
  name: 'pf-field-type-match',
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
    matchLabel: {
      type: String
    },
    fields: {
      type: Array,
      default: () => { return [] }
    },
    vuelidate: {
      type: Object,
      default: () => { return {} }
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      default:                    { type: null, match: null }, // default value
      /* Generic field types */
      noValueType:                fieldType.NONE,
      integerValueType:           fieldType.INTEGER,
      substringValueType:         fieldType.SUBSTRING,
      /* Custom element field types */
      connectionSubTypeValueType: fieldType.CONNECTION_SUB_TYPE,
      connectionTypeValueType:    fieldType.CONNECTION_TYPE,
      datetimeValueType:          fieldType.DATETIME,
      prefixmultiplerValueType:   fieldType.PREFIXMULTIPLIER,
      timeBalanceValueType:       fieldType.TIME_BALANCE,
      /* Promise based field types */
      adminroleValueType:         fieldType.ADMINROLE,
      durationValueType:          fieldType.DURATION,
      realmValueType:             fieldType.REALM,
      roleValueType:              fieldType.ROLE,
      roleByNameValueType:        fieldType.ROLE_BY_NAME,
      switchValueType:            fieldType.SWITCHE,
      switchGroupValueType:       fieldType.SWITCH_GROUP,
      tenantValueType:            fieldType.TENANT
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
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Action type "{type}" is not valid, ignoring.', { type: type }) })
          this.$set(this.inputValue, 'type', this.default.type) // clear `type`
          this.$set(this.inputValue, 'match', this.default.match) // clear `value`
          return null
        }
        return type
      },
      set (newType) {
        this.$set(this.inputValue, 'type', newType || this.default.type)
        this.$set(this.inputValue, 'match', this.default.match) // clear `value`
        this.emitValidations()
        this.$nextTick(() => { // wait until DOM updates with new type
          this.focusMatch()
        })
      }
    },
    localMatch: {
      get () {
        return (this.inputValue && 'match' in this.inputValue) ? this.inputValue.match : this.default.match
      },
      set (newValue) {
        this.$set(this.inputValue, 'match', newValue || this.default.match)
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
          if (fieldTypeValues[type](this)) options.push(...fieldTypeValues[type](this))
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
    matchVuelidateModel () {
      return this.getVuelidateModel('match')
    },
    matchInvalidFeedback () {
      return this.getInvalidFeedback('match')
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
        this.focusMatch()
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
    focusMatch () {
      this.focusIndex(1)
    }
  },
  created () {
    this.emitValidations()
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
