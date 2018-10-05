<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()" :class="['sortablefields-element', { 'is-focus': drag }, { 'mb-0': !columnLabel }]"
    >
    <b-input-group class="input-group-sortablefields">
      <b-container fluid class="px-0"
        @mouseleave="onMouseLeave()"
      >
        <draggable
          v-model="inputValue"
          :options="{handle: '.draghandle', dragClass: 'dragclass'}"
          @start="onDragStart"
          @end="onDragEnd"
        >
          <b-form-row
            v-for="(value, index) in inputValue"
            class="text-secondary align-items-center"
            align-v="center"
            :key="index"
            @mouseenter="onMouseEnter(index)"
            @mousemove="onMouseEnter(index)"
            no-gutter
          >
            <b-col col v-if="sortable && hover === index && inputValue.length > 1" class="draghandle text-center"><icon name="th"></icon></b-col>
            <b-col col v-else class="dragindex text-center"><b-badge variant="light">{{ index + 1 }}</b-badge></b-col>
            <b-col cols="4" class="text-left py-1" align-self="start">

              <pf-form-chosen
                :value="inputValue[index].type"
                :id="'chosen-' + index"
                label="text"
                track-by="value"
                :options="fields"
                @input="setType(index, $event)"
              ></pf-form-chosen>

            </b-col>
            <b-col cols="6" class="text-left py-1" align-self="start">

              <!--
                - Don't use 'v-model='...,
                - instead use ':value=' and '@input=' combination
              -->

              <!-- BEGIN ADMINROLE -->
              <pf-form-chosen v-if="isFieldType(adminroleValueType, inputValue[index])"
                :value="inputValue[index].value"
                label="name"
                track-by="value"
                :options="values(inputValue[index])"
                :validation="validation[index]"
                :invalid-feedback="getInvalidFeedbackExternalValue(index)"
                @input="setValue(index, $event)"
              ></pf-form-chosen>

              <!-- BEGIN ROLE -->
              <pf-form-chosen v-if="isFieldType(roleValueType, inputValue[index])"
                :value="inputValue[index].value"
                label="name"
                track-by="value"
                :options="values(inputValue[index])"
                :validation="validation[index]"
                :invalid-feedback="getInvalidFeedbackExternalValue(index)"
                @input="setValue(index, $event)"
              ></pf-form-chosen>

              <!-- BEGIN TENANT -->
              <pf-form-chosen v-if="isFieldType(tenantValueType, inputValue[index])"
                :value="inputValue[index].value"
                label="name"
                track-by="value"
                :options="values(inputValue[index])"
                :validation="validation[index]"
                :invalid-feedback="getInvalidFeedbackExternalValue(index)"
                @input="setValue(index, $event)"
              ></pf-form-chosen>

              <!-- BEGIN DATETIME -->
              <pf-form-datetime v-if="isFieldType(datetimeValueType, inputValue[index])"
                :value="inputValue[index].value"
                :config="{useCurrent: true}"
                :validation="validation[index]"
                :invalid-feedback="getInvalidFeedbackExternalValue(index)"
                @input="setValue(index, $event)"
              ></pf-form-datetime>

              <!-- BEGIN DURATION -->
              <pf-form-chosen v-if="isFieldType(durationValueType, inputValue[index])"
                :value="inputValue[index].value"
                label="name"
                track-by="value"
                :options="values(inputValue[index])"
                :validation="validation[index]"
                :invalid-feedback="getInvalidFeedbackExternalValue(index)"
                @input="setValue(index, $event)"
              ></pf-form-chosen>

              <!-- BEGIN PREFIXMULTIPLER -->
              <pf-form-prefix-multiplier v-if="isFieldType(prefixmultiplerValueType, inputValue[index])"
                :value="inputValue[index].value"
                :validation="validation[index]"
                :invalid-feedback="getInvalidFeedbackExternalValue(index)"
                @input="setValue(index, $event)"
              ></pf-form-prefix-multiplier>

            </b-col>
            <b-col col class="text-center text-nowrap">
              <icon name="plus-circle" class="cursor-pointer mx-1" @click.native.stop.prevent="rowAdd(index)"></icon>
              <icon name="minus-circle" v-if="inputValue.length > 1" class="cursor-pointer mx-1" @click.native.stop.prevent="rowDel(index)"></icon>
            </b-col>
          </b-form-row>
        </draggable>

      </b-container>
    </b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import draggable from 'vuedraggable'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import pfMixinValidation from '@/components/pfMixinValidation'
import {
  pfFieldType as fieldType,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'

export default {
  name: 'pf-form-sortable-fields',
  mixins: [
    pfMixinValidation
  ],
  components: {
    draggable,
    'pf-form-chosen': pfFormChosen,
    'pf-form-datetime': pfFormDatetime,
    'pf-form-prefix-multiplier': pfFormPrefixMultiplier
  },
  props: {
    value: {
      type: Array
    },
    columnLabel: {
      type: String
    },
    labelCols: {
      type: Number,
      default: 3
    },
    text: {
      type: String,
      default: null
    },
    fields: {
      type: Array,
      default: null
    },
    sortable: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      valuePlaceholder:         { type: null, value: null },
      hover:                    null,
      drag:                     false,
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
      tenantValueType:          fieldType.TENANT
    }
  },
  computed: {
    inputValue: {
      /**
        * `inputValue` has 2 different models:
        *
        *   1. Internal Model (uncompressed): In this model we keep the entire type/value in-tact for use with the various pfForm* components.
        *     Example: [
        *         { "type": { "value": "set_bandwidth_balance", "text": "Bandwidth balance", "types": [ "prefixmultiplier" ] }, "value": 64 },
        *         { "type": { "value": "set_access_duration", "text": "Access duration", "types": [ "duration" ] }, "value": { "name": "12 hours", "value": "12h" } },
        *         { "type": { "value": "set_access_level", "text": "Access level", "types": [ "adminrole" ] }, "value": { "value": "User Manager", "name": "User Manager" } },
        *         { "type": { "value": "mark_as_sponsor", "text": "Mark as sponsor", "types": [ "none" ] }, "value": null },
        *         { "type": { "value": "set_role", "text": "Role", "types": [ "role" ] }, "value": { "value": "1", "name": "default", "text": "default - Placeholder role/category, feel free to edit" } },
        *         { "type": { "value": "set_tenant_id", "text": "Tenant ID", "types": [ "tenant" ] }, "value": { "value": "1", "name": "default" } },
        *         { "type": { "value": "set_time_balance", "text": "Time balance", "types": [ "duration" ] }, "value": { "name": "12 hours", "value": "12h" } },
        *         { "type": { "value": "set_unreg_date", "text": "Unregistration date", "types": [ "datetime" ] }, "value": 1973-08-05 13:00:00" }
        *        ]
        *
        *   2. External Model (compressed): In this model we compress the internal model into somewthing more clean and useable by the parent component.
        *     Example: [
        *         { "type": "set_bandwidth_balance", "value": 64 },
        *         { "type": "set_access_duration", "value": "12h" },
        *         { "type": "set_access_level", "value": "User Manager" },
        *         { "type": "mark_as_sponsor", "value": null },
        *         { "type": "set_role", "value": "1" },
        *         { "type": "set_tenant_id", "value": "1" },
        *         { "type": "set_time_balance", "value": "12h" },
        *         { "type": "set_unreg_date", "value": "1973-08-05 13:00:00" }
        *       ]
        *
      **/
      get () {
        const value = (this.value) ? this.value : [this.valuePlaceholder]
        const uncompressedValue = value.map(row => {
          let field = this.fields.find(field => field.value === row.type)
          return {
            type: (row.type && typeof row.type !== 'object')
              ? field
              : row.type,
            value: (row.value && typeof row.value !== 'object')
              ? this.values({ type: field }).find(value => value.value === row.value) || row.value
              : row.value
          }
        })
        return uncompressedValue
      },
      set (newValue) {
        const compressedValue = newValue.map(row => {
          return {
            type: ((row.type && row.type.value) ? this.fields.find(field => field.value === row.type.value).value : row.type),
            value: ((row.value && row.value.value) ? row.value.value : row.value)
          }
        })
        this.$emit('input', compressedValue)
        this.emitExternalValidations()
      }
    }
  },
  methods: {
    setType (index, type) {
      let inputValue = JSON.parse(JSON.stringify(this.inputValue))
      inputValue[index].type = type
      inputValue[index].value = null
      this.inputValue = inputValue
      this.emitExternalValidations()
    },
    setValue (index, value) {
      let inputValue = JSON.parse(JSON.stringify(this.inputValue))
      inputValue[index].value = value
      this.inputValue = inputValue
    },
    rowAdd (index) {
      let inputValue = this.inputValue
      // push placeholder into middle of array
      this.inputValue = [...inputValue.slice(0, index + 1), this.valuePlaceholder, ...inputValue.slice(index + 1)]
      this.$forceUpdate()
      this.emitExternalValidations()
    },
    rowDel (index) {
      let inputValue = JSON.parse(JSON.stringify(this.inputValue))
      inputValue.splice(index, 1)
      this.inputValue = inputValue
      if (this.inputValue.length === 0) {
        this.rowAdd(0)
      } else {
        this.$forceUpdate()
        this.emitExternalValidations()
      }
    },
    onDragStart (event) {
      this.drag = true
      this.hover = null
    },
    onDragEnd (event) {
      this.drag = false
    },
    onMouseEnter (index) {
      if (this.drag) return
      this.hover = index
    },
    onMouseLeave () {
      this.hover = null
    },
    values (inputValue) {
      if (!inputValue || !inputValue.type) return []
      let index = this.fields.findIndex(field => inputValue.type.value === field.value)
      let values = []
      if (index >= 0) {
        let field = this.fields[index]
        for (const type of field.types) {
          if (fieldTypeValues[type]) {
            values.push(...fieldTypeValues[type](this.$store))
          }
        }
      }
      return values
    },
    isFieldType (type, inputValue) {
      if (!inputValue.type) return false
      let index = this.fields.findIndex(field => inputValue.type.value === field.value)
      if (index >= 0) {
        let field = this.fields[index]
        if (field.types.includes(type)) {
          return true
        }
      }
      return false
    },
    getValidations () {
      let eachInputValue = {}
      this.inputValue.forEach((input, index) => {
        let field = this.fields.find(field => input.type && field.value === input.type.value)
        if (field && field.validators) {
          eachInputValue[field.value] = { value: field.validators }
        } else if (field && field.value) {
          // no validations
          eachInputValue[field.value] = {/* ignore */}
        } else {
          // 1 or more undefined field(s)
          eachInputValue[null] = {/* ignore */}
        }
      })
      if (eachInputValue !== {}) {
        // use functional validations
        // https://github.com/monterail/vuelidate/issues/166#issuecomment-319924309
        return { ...this.inputValue.map(input => eachInputValue[(input.type && input.type.value) ? input.type.value : null]) }
      }
      return {}
    },
    getInvalidFeedbackExternalValue (index) {
      let feedback = []
      if (index !== undefined) {
        const inputValue = this.validation[index] /* use external vuelidate $v model */
        if (inputValue.value) {
          const validationModel = inputValue.value
          if (validationModel) {
            Object.entries(validationModel.$params).forEach(([key, value]) => {
              if (validationModel[key] === false) {
                feedback.push(key.trim())
              }
            })
          }
        }
      }
      return feedback.join(' ')
    },
    emitExternalValidations () {
      // debounce to avoid emit storm,
      // delay to allow internal inputValue to update before building external validations
      if (this.emitExternalValidationsTimeout) clearTimeout(this.emitExternalValidationsTimeout)
      this.emitExternalValidationsTimeout = setTimeout(() => {
        this.$emit('validations', this.getValidations())
      }, 100)
    }
  },
  mounted () {
    this.emitExternalValidations()
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/border-radius";
@import "../../node_modules/bootstrap/scss/mixins/transition";
@import "../styles/variables";

.sortablefields-element {
  .input-group-sortablefields {
    border: 1px solid $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;
  }
  &.is-focus {
    .input-group-sortablefields {
      border-color: $input-focus-border-color;
      box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
    }
  }
  &.is-invalid {
    .input-group-sortablefields {
      border-color: $form-feedback-invalid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
    }
  }
  .form-row {
    &:not(:last-child) {
      border-bottom: 1px solid $input-focus-bg;
    }
  }
}
.draghandle {
  cursor: grab;
}
.dragindex {
  font-size: 80%
}
.cursor-pointer {
  cursor: pointer;
}
</style>
