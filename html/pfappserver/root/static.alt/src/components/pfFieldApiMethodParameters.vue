<template>
  <b-form-row class="pf-field-api-method-parameters mx-0 mb-1 px-0" align-v="center">
    <b-col v-if="$slots.prepend" cols="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="5" align-self="start">

      <pf-form-chosen ref="api_method"
        class="mr-1"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.api_method`"
        label="text"
        track-by="value"
        :placeholder="apiMethodLabel"
        :options="fields"
        :disabled="disabled"
        collapse-object
      ></pf-form-chosen>

    </b-col>
    <b-col cols="5" align-self="start" class="pl-1">

      <!-- Type: SUBSTRING -->
      <pf-form-input ref="api_parameters" v-if="isComponentType([componentType.SUBSTRING])"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.api_parameters`"
        :disabled="disabled"
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
import pfMixinForm from '@/components/pfMixinForm'
import {
  pfComponentType as componentType,
  pfFieldTypeComponent as fieldTypeComponent,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'

export default {
  name: 'pf-field-api-method-parameters',
  components: {
    pfFormChosen,
    pfFormInput
  },
  mixins: [
    pfMixinForm
  ],
  props: {
    value: {
      type: Object,
      default: () => { return { api_method: null, api_parameters: null } }
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
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      default: { api_method: null, api_parameters: null }, // default value
      componentType // @/globals/pfField
    }
  },
  computed: {
    inputValue: {
      get () {
        return { ...this.default, ...this.formStoreValue } // use FormStore
      },
      set (newValue) {
        this.formStoreValue = newValue // use FormStore
      }
    },
    localApiMethod () {
      return this.inputValue.api_method
    },
    localApiParameters () {
      return this.inputValue.api_parameters
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
          if (type in fieldTypeValues) options.push(...fieldTypeValues[type]())
        }
      }
      return options
    },
    moments () {
      if ('moments' in this.field) return this.field.moments
      return []
    }
  },
  methods: {
    isComponentType (componentTypes) {
      if (!this.localApiMethod) return false
      const index = this.fields.findIndex(field => field.value === this.localApiMethod)
      if (index >= 0) {
        const field = this.fields[index]
        for (let t = 0; t < componentTypes.length; t++) {
          if (field.types.map(type => fieldTypeComponent[type]).includes(componentTypes[t])) return true
        }
      }
      return false
    },
    focus () {
      if (this.localApiMethod) {
        this.focusApiParameters()
      } else {
        this.focusApiMethod()
      }
    },
    focusApiMethod () {
      const { $refs: { api_method: { focus = () => {} } = {} } = {} } = this
      focus()
    },
    focusApiParameters () {
      const { $refs: { api_parameters: { focus = () => {} } = {} } = {} } = this
      focus()
    }
  },
  watch: {
    localApiMethod: {
      handler: function () {
        const { field: { sibling: { api_parameters: { default: apiParametersDefault = null } = {} } = {} } = {} } = this
        if (!this.drag) { // don't set or focus when being dragged
          this.$set(this.formStoreValue, 'api_parameters', apiParametersDefault) // clear parameters
          this.$nextTick(() => {
            this.focusApiParameters()
          })
        }
      }
    }
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
