<template>
  <b-form-row class="pf-field-attribute-operator-value mx-0 mb-1 px-0" align-v="center"
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" sm="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col class="pl-0" sm="3" align-self="start">

      <pf-form-chosen
        v-model="localAttribute"
        ref="localAttribute"
        label="text"
        track-by="value"
        :placeholder="attributeLabel"
        :options="fields"
        :vuelidate="attributeVuelidateModel"
        :invalid-feedback="attributeInvalidFeedback"
        :disabled="disabled"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col class="pl-1" sm="3" align-self="start">

      <pf-form-chosen v-if="localAttribute"
        v-model="localOperator"
        ref="localOperator"
        label="text"
        track-by="value"
        :placeholder="operatorLabel"
        :options="operators"
        :disabled="disabled || operators.length === 0"
        :vuelidate="operatorVuelidateModel"
        :invalid-feedback="operatorInvalidFeedback"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col class="pl-1" sm="4" align-self="start">

      <!-- Types: LDAPATTRIBUTE, SUBSTRING, TIME_PERIOD -->
      <pf-form-input v-if="
          isAttributeType(ldapAttributeConditionType) ||
          isAttributeType(substringConditionType) ||
          isAttributeType(timePeriodConditionType)
        "
        v-model="localValue"
        ref="localValue"
        :placeholder="valueLabel"
        :vuelidate="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
        :disabled="disabled"
      ></pf-form-input>

      <!-- Type: TIME -->
      <pf-form-datetime v-else-if="isAttributeType(timeConditionType)"
        v-model="localValue"
        ref="localValue"
        :config="{useCurrent: false, datetimeFormat: 'HH:mm'}"
        placeholder="HH:mm"
        :vuelidate="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
        :disabled="disabled"
      ></pf-form-datetime>

      <!-- Type: CONNECTION -->
      <pf-form-chosen v-else-if="isAttributeType(connectionConditionType)"
        v-model="localValue"
        ref="localValue"
        group-label="group"
        group-values="items"
        label="text"
        track-by="value"
        :placeholder="valueLabel"
        :options="values"
        :vuelidate="valueVuelidateModel"
        :invalid-feedback="valueInvalidFeedback"
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
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import {
  pfAuthenticationConditionType as authenticationConditionType,
  pfAuthenticationConditionOperators as authenticationConditionOperators,
  pfAuthenticationConditionValues as authenticationConditionValues
} from '@/globals/pfAuthenticationConditions'
import { required } from 'vuelidate/lib/validators'

export default {
  name: 'pf-field-attribute-operator-value',
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
      default:                    { attribute: null, operator: null, value: null }, // default value
      noConditionType:            authenticationConditionType.NONE,
      connectionConditionType:    authenticationConditionType.CONNECTION,
      ldapAttributeConditionType: authenticationConditionType.LDAPATTRIBUTE,
      substringConditionType:     authenticationConditionType.SUBSTRING,
      timeConditionType:          authenticationConditionType.TIME,
      timePeriodConditionType:    authenticationConditionType.TIMEPERIOD
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
    localAttribute: {
      get () {
        let attribute = (this.inputValue && 'attribute' in this.inputValue) ? this.inputValue.attribute : this.default.attribute
        // check to see if `attribute` exists in our available fields
        if (attribute && !this.fields.find(field => field.value === attribute)) {
          // discard
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Condition attribute "{attribute}" is not valid, ignoring...', { attribute: attribute }) })
          this.$set(this.inputValue, 'attribute', this.default.attribute) // clear `attribute`
          this.$set(this.inputValue, 'operator', this.default.operator) // clear `operator`
          this.$set(this.inputValue, 'value', this.default.value) // clear `value`
          return null
        }
        return attribute
      },
      set (newAttribute) {
        this.$set(this.inputValue, 'attribute', newAttribute || this.default.attribute)
        this.$set(this.inputValue, 'operator', this.default.operator) // clear `operator`
        this.$set(this.inputValue, 'value', this.default.value) // clear `value`
        this.emitValidations()
        this.$nextTick(() => { // wait until DOM updates with new attribute
          this.focusOperator()
        })
      }
    },
    localOperator: {
      get () {
        return (this.inputValue && 'operator' in this.inputValue) ? this.inputValue.operator : this.default.operator
      },
      set (newValue) {
        this.$set(this.inputValue, 'operator', newValue || this.default.operator)
        this.emitValidations()
        this.$nextTick(() => { // wait until DOM updates with new attribute
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
          if (authenticationConditionOperators[type]) {
            operators.push(...Object.keys(authenticationConditionOperators[type]).map(oper => { return { text: oper, value: oper } }))
          }
        }
      }
      return operators
    },
    values () {
      if (!this.localAttribute) return []
      let values = []
      if (this.fieldIndex >= 0) {
        const field = this.field
        for (const type of field.types) {
          if (authenticationConditionValues[type]) {
            values.push(...authenticationConditionValues[type](this.$store))
          }
        }
      }
      return values
    },
    attributeVuelidateModel () {
      return this.getVuelidateModel('attribute')
    },
    attributeInvalidFeedback () {
      return this.getInvalidFeedback('attribute')
    },
    operatorVuelidateModel () {
      return this.getVuelidateModel('operator')
    },
    operatorInvalidFeedback () {
      return this.getInvalidFeedback('operator')
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
    isAttributeType (type) {
      if (!this.localAttribute) return false
      const index = this.fields.findIndex(field => field.value === this.localAttribute)
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
      return { attribute: { [this.$i18n.t('Attribute required.')]: required } }
    },
    emitValidations () {
      this.$emit('validations', this.buildLocalValidations())
    },
    focus () {
      if (this.localAttribute) {
        this.focusValue()
      } else {
        this.focusType()
      }
    },
    focusIndex (index = 0) {
      const { [index]: { $refs: { input: { $el } } } } = Object.values(this.$refs)
      if ('focus' in $el) $el.focus()
    },
    focusType () {
      this.focusIndex(0)
    },
    focusOperator () {
      this.focusIndex(1)
    },
    focusValue () {
      this.focusIndex(2)
    }
  },
  created () {
    this.emitValidations()
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
