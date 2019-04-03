<template>
  <b-form-row class="pf-field-api-method-parameters mx-0 mb-1 px-0" align-v="center"
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" cols="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="5" align-self="start">

      <pf-form-chosen
        v-model="localApiMethod"
        v-on="forwardListeners"
        ref="localApiMethod"
        label="text"
        track-by="value"
        :placeholder="apiMethodLabel"
        :options="fields"
        :vuelidate="apiMethodVuelidateModel"
        :invalid-feedback="apiMethodInvalidFeedback"
        class="mr-1"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col cols="5" align-self="start" class="pl-1">

      <!-- Type: SUBSTRING -->
      <pf-form-input v-if="isFieldType(substringValueType)"
        v-model="localApiParameters"
        ref="localApiParameters"
        :vuelidate="apiParametersVuelidateModel"
        :invalid-feedback="apiParametersInvalidFeedback"
      ></pf-form-input>

    </b-col>
    <b-col v-if="$slots.append" cols="1" align-self="start" class="text-center col-form-label">
      <slot name="append"></slot>
    </b-col>
  </b-form-row>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import {
  pfFieldType as fieldType,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import { required } from 'vuelidate/lib/validators'

export default {
  name: 'pf-field-api-method-parameters',
  components: {
    pfFormChosen,
    pfFormInput
  },
  props: {
    value: {
      type: Object,
      default: () => { return this.default }
    },
    apiMethodLabel: {
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
      default:            { api_method: null, api_parameters: null }, // default value
      /* Generic field types */
      substringValueType: fieldType.SUBSTRING
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
    localApiMethod: {
      get () {
        let apiMethod = (this.inputValue && 'api_method' in this.inputValue) ? this.inputValue.api_method : this.default.api_method
        // check to see if `api_method` exists in our available fields
        if (apiMethod && !this.fields.find(field => field.value === apiMethod)) {
          // discard
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Action API Method "{api_method}" is not valid, ignoring.', { api_method: apiMethod }) })
          this.$set(this.inputValue, 'api_method', this.default.api_method) // clear `api_method`
          this.$set(this.inputValue, 'api_parameters', this.default.api_parameters) // clear `api_parameters`
          return null
        }
        return apiMethod
      },
      set (newApiMethod) {
        this.$set(this.inputValue, 'api_method', newApiMethod || this.default.api_method)
        const field = this.fields.find(field => field.value === newApiMethod)
        if (field) {
          // selected
          this.$set(this.inputValue, 'api_parameters', field.defaultApiParameters || this.default.api_parameters) // set `api_parameters`
        } else {
          // null
          this.$set(this.inputValue, 'api_parameters', this.default.api_parameters) // clear `api_parameters`
        }
        this.emitValidations()
        this.$nextTick(() => { // wait until DOM updates with new api_method
          this.focusApiParameters()
        })
      }
    },
    localApiParameters: {
      get () {
        return (this.inputValue && 'api_parameters' in this.inputValue) ? this.inputValue.api_parameters : this.default.api_parameters
      },
      set (newApiParameters) {
        this.$set(this.inputValue, 'api_parameters', newApiParameters || this.default.api_parameters)
        this.emitValidations()
      }
    },
    field () {
      if (this.localApiMethod) return this.fields.find(field => field.value === this.localApiMethod)
      return null
    },
    fieldIndex () {
      if (this.localApiMethod) {
        const index = this.fields.findIndex(field => field.value === this.localApiMethod)
        if (index >= 0) return index
      }
      return null
    },
    options () {
      if (!this.localApiMethod) return []
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
    apiMethodVuelidateModel () {
      return this.getVuelidateModel('api_method')
    },
    apiMethodInvalidFeedback () {
      return this.getInvalidFeedback('api_method')
    },
    apiParametersVuelidateModel () {
      return this.getVuelidateModel('api_parameters')
    },
    apiParametersInvalidFeedback () {
      return this.getInvalidFeedback('api_parameters')
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    isFieldType (type) {
      if (!this.localApiMethod) return false
      const index = this.fields.findIndex(field => field.value === this.localApiMethod)
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
      return { api_method: { [this.$i18n.t('API Method required.')]: required } }
    },
    emitValidations () {
      this.$emit('validations', this.buildLocalValidations())
    },
    focus () {
      if (this.localApiMethod) {
        this.focusApiParameters()
      } else {
        this.focusApiMethod()
      }
    },
    focusIndex (index = 0) {
      const refs = Object.values(this.$refs)
      if (index in refs) {
        const { $refs: { input: { $el } } } = refs[index]
        if ($el && 'focus' in $el) $el.focus()
      }
    },
    focusApiMethod () {
      this.focusIndex(0)
    },
    focusApiParameters () {
      this.focusIndex(1)
    }
  },
  created () {
    this.emitValidations()
  }
}
</script>

<style lang="scss">
.pf-field-api-method-parameters {
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-right: 0px;
      padding-left: 0px;
    }
  }
}
</style>
