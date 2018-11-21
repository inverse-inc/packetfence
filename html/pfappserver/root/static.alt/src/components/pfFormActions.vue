<!--
 * Component to manage sortable lists (arrays).
 *
 * Supports:
 *  sortable drag-and-drop, must be explicitly enabled
 *  vuelidate on field |type|
 *  vuelidate on field |value|
 *
 * Basic Usage:
 *
 *  <template>
 *    <pf-form-actions
 *      v-model="actions"
 *      :fields="actionFields"
 *    ></pf-form-actions>
 *  </template>
 *
 * Extended Usage:
 *
 *  <template>
 *    <pf-form-actions
 *      sortable
 *      v-model="actions"
 *      :column-label="$t('Actions')"
 *      :type-label="$t('Choose type')"
 *      :value-label="$t('Choose value')"
 *      :fields="actionFields"
 *      :validation="$v.actions"
 *      :invalid-feedback="[
 *        { [$t('One or more errors exist.')]: !$v.actions.anyError }
 *      ]"
 *      @validations="actionsValidations = $event"
 *    ></pf-form-actions>
 *  </template>
 *
 * Properties:
 *
 *    `sortable`: (boolean) -- enable drag-and-drop reordering, default: false
 *
 *    `v-model`: (Object) -- inputValue setter/getter, returns an array
 *
 *    `fields`: (array) -- the fields to use in the |type| and |value| fields -- [
 *      {
 *        value: (string) -- the field |type|
 *        text: (string) -- the field label
 *        types: (array) -- [
 *          type: (string) -- See globals/pfFields.js,
 *          ...
 *        ],
 *        validators: (object) -- {
 *          type: (object) -- vuelidate key/value pairs for this field |type| -- {
 *            (array) -- [
 *              key: (string) -- the string to output on vuelidate error,
 *              value: (function) -- the vuelidate function to test this field |type|
 *            ],
 *            ...
 *          },
 *          value: (object) -- vuelidate key/value pairs for this field |value| -- {
 *            (array) -- [
 *              key: (string) -- the string to output on vuelidate error,
 *              value: (function) -- the vuelidate function to test this field |value|
 *            ],
 *            ...
 *          }
 *        }
 *      },
 *      ...
 *    ]
 *
 *    `validation` (vuelidate object) -- the local vuelidate model where this component attaches itself.
 *      This component does not keep a local vuelidate model, but rather uses the parent's vuelidate model
 *      to validate. See `@validations` event.
 *
 * Events:
 *
 *    `@validations` (event) -- the component uses the parent's vuelidate model for validation.
 *      The components vuelidate model is emitted through this event whenever the internal model changes.
 *
-->
<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="sortablefields-element" :class="{ 'is-focus': drag, 'mb-0': !columnLabel }"
    >
    <b-input-group class="input-group-sortablefields">

      <!--
         - Vacuum-up label click event.
         - See: https://github.com/bootstrap-vue/bootstrap-vue/issues/2063
      -->
      <input type="text" name="vaccum" :value="null" style="position: absolute; width: 1px; height: 1px; padding: 0px; border: 0px; visibility: hidden;" />

      <b-container fluid class="px-0"
        v-bind="$attrs"
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
            class="text-secondary py-1"
            align-v="center"
            :key="index"
            @mouseenter="onMouseEnter(index)"
            @mousemove="onMouseEnter(index)"
            no-gutter
          >
            <b-col col align-self="start" class="draghandle text-center col-form-label pt-2" v-if="sortable && hover === index && inputValue.length > 1">
              <icon name="th" v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"></icon>
            </b-col>
            <b-col col align-self="start" class="dragindex text-center col-form-label pt-2" v-else>
              {{ index + 1 }}
            </b-col>
            <b-col cols="4" class="text-left" align-self="start">

              <pf-form-chosen
                :value="inputValue[index].type"
                :id="'chosen-' + index"
                :ref="'type-' + index"
                label="text"
                track-by="value"
                :placeholder="typeLabel"
                :options="fields"
                :validation="getTypeValidation(index)"
                :invalid-feedback="getTypeInvalidFeedback(index)"
                @input="setType(index, $event)"
                collapse-object
              ></pf-form-chosen>

            </b-col>
            <b-col cols="6" class="text-left" align-self="start">

              <!--
                - Don't use 'v-model='...,
                - instead use ':value=' and '@input=' combination
              -->

              <!-- BEGIN ADMINROLE -->
              <pf-form-chosen v-if="isFieldType(adminroleValueType, inputValue[index])"
                :value="inputValue[index].value"
                :ref="'value-' + index"
                label="name"
                track-by="value"
                :placeholder="valueLabel"
                :options="values(inputValue[index])"
                :validation="getValueValidation(index)"
                :invalid-feedback="getValueInvalidFeedback(index)"
                @input="setValue(index, $event)"
                collapse-object
              ></pf-form-chosen>

              <!-- BEGIN ROLE -->
              <pf-form-chosen v-if="isFieldType(roleValueType, inputValue[index])"
                :value="inputValue[index].value"
                :ref="'value-' + index"
                label="name"
                track-by="value"
                :placeholder="valueLabel"
                :options="values(inputValue[index])"
                :validation="getValueValidation(index)"
                :invalid-feedback="getValueInvalidFeedback(index)"
                @input="setValue(index, $event)"
                collapse-object
              ></pf-form-chosen>

              <!-- BEGIN ROLE_BY_NAME -->
              <pf-form-chosen v-if="isFieldType(roleByNameValueType, inputValue[index])"
                :value="inputValue[index].value"
                :ref="'value-' + index"
                label="name"
                track-by="value"
                :placeholder="valueLabel"
                :options="values(inputValue[index])"
                :validation="getValueValidation(index)"
                :invalid-feedback="getValueInvalidFeedback(index)"
                @input="setValue(index, $event)"
                collapse-object
              ></pf-form-chosen>

              <!-- BEGIN TENANT -->
              <pf-form-chosen v-if="isFieldType(tenantValueType, inputValue[index])"
                :value="inputValue[index].value"
                :ref="'value-' + index"
                label="name"
                track-by="value"
                :placeholder="valueLabel"
                :options="values(inputValue[index])"
                :validation="getValueValidation(index)"
                :invalid-feedback="getValueInvalidFeedback(index)"
                @input="setValue(index, $event)"
                collapse-object
              ></pf-form-chosen>

              <!-- BEGIN DATETIME -->
              <pf-form-datetime v-if="isFieldType(datetimeValueType, inputValue[index])"
                :value="inputValue[index].value"
                :ref="'value-' + index"
                :config="{useCurrent: true, format: 'YYYY-MM-DD HH:mm:ss'}"
                :moments="getMoments(index)"
                :validation="getValueValidation(index)"
                :invalid-feedback="getValueInvalidFeedback(index)"
                @input="setValue(index, $event)"
              ></pf-form-datetime>

              <!-- BEGIN DURATION -->
              <pf-form-chosen v-if="isFieldType(durationValueType, inputValue[index])"
                :value="inputValue[index].value"
                :ref="'value-' + index"
                label="name"
                track-by="value"
                :placeholder="valueLabel"
                :options="values(inputValue[index])"
                :validation="getValueValidation(index)"
                :invalid-feedback="getValueInvalidFeedback(index)"
                @input="setValue(index, $event)"
                collapse-object
              ></pf-form-chosen>

              <!-- BEGIN PREFIXMULTIPLER -->
              <pf-form-prefix-multiplier v-if="isFieldType(prefixmultiplerValueType, inputValue[index])"
                :value="inputValue[index].value"
                :ref="'value-' + index"
                :validation="getValueValidation(index)"
                :invalid-feedback="getValueInvalidFeedback(index)"
                @input="setValue(index, $event)"
              ></pf-form-prefix-multiplier>

            </b-col>
            <b-col col align-self="start" class="text-center text-nowrap col-form-label pt-2">
              <icon name="minus-circle" v-if="inputValue.length > 1" :class="['cursor-pointer mx-1', { 'text-primary': ctrlKey, 'text-secondary': !ctrlKey }]" v-b-tooltip.hover.left.d300 :title="$t((ctrlKey) ? 'Delete All Actions' : 'Delete Action')" @click.native.stop.prevent="rowDel(index)"></icon>
              <icon name="plus-circle" :class="['cursor-pointer mx-1', { 'text-primary': ctrlKey, 'text-secondary': !ctrlKey }]" v-b-tooltip.hover.left.d300 :title="$t((ctrlKey) ? 'Clone Action' : 'Add Action')" @click.native.stop.prevent="rowAdd(index + 1)"></icon>
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
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'
import pfMixinValidation from '@/components/pfMixinValidation'
import {
  pfFieldType as fieldType,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'
import { required } from 'vuelidate/lib/validators'

export default {
  name: 'pf-form-actions',
  mixins: [
    pfMixinCtrlKey,
    pfMixinValidation
  ],
  components: {
    draggable,
    pfFormChosen,
    pfFormDatetime,
    pfFormPrefixMultiplier
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
    validation: {
      type: Object,
      default: null
    },
    sortable: {
      type: Boolean,
      default: false
    },
    typeLabel: {
      type: String
    },
    valueLabel: {
      type: String
    }
  },
  data () {
    return {
      valuePlaceHolder:         { type: null, value: null },
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
      roleByNameValueType:      fieldType.ROLE_BY_NAME,
      tenantValueType:          fieldType.TENANT
    }
  },
  computed: {
    inputValue: {
      get () {
        return (this.value) ? this.value : [this.valuePlaceHolder]
      },
      set (newValue) {
        this.$emit('input', newValue)
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
      // focus the value element in this row
      this.setFocus('value-' + index)
    },
    setValue (index, value) {
      let inputValue = JSON.parse(JSON.stringify(this.inputValue))
      inputValue[index].value = value
      this.inputValue = inputValue
      this.emitExternalValidations()
    },
    setFocus (ref) {
      this.$nextTick(() => {
        if (ref in this.$refs) {
          const reference = this.$refs[ref][0]
          if (reference && '$refs' in reference && 'input' in reference.$refs) {
            const input = reference.$refs.input
            if ('$el' in input) {
              input.$el.focus()
            }
          }
        }
      })
    },
    rowAdd (index, clone = this.ctrlKey) {
      let inputValue = this.inputValue
      let valuePlaceHolder = (clone && (index - 1) in inputValue)
        ? JSON.parse(JSON.stringify(inputValue[index - 1])) // clone
        : JSON.parse(JSON.stringify(this.valuePlaceHolder)) // use placeholder, dereference
      // push placeholder into middle of array
      this.inputValue = [...inputValue.slice(0, index), valuePlaceHolder, ...inputValue.slice(index)]
      this.emitExternalValidations()
      // focus the type element in new row
      if (!clone) { // focusing pfFormChosen steals ctrlKey's onkeyup event
        this.setFocus('type-' + index)
      }
    },
    rowDel (index, deleteAll = this.ctrlKey) {
      if (deleteAll) {
        this.inputValue = [] // delete all rows
      } else {
        this.inputValue.splice(index, 1) // delete 1 row
      }
      this.$nextTick(() => {
        if (this.inputValue.length === 0) {
          this.rowAdd(0)
        } else {
          this.emitExternalValidations()
        }
      })
    },
    onDragStart (event) {
      this.drag = true
      this.hover = null
    },
    onDragEnd (event) {
      this.drag = false
      this.emitExternalValidations()
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
      const index = this.fields.findIndex(field => field.value === inputValue.type)
      let values = []
      if (index >= 0) {
        const field = this.fields[index]
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
      const index = this.fields.findIndex(field => field.value === inputValue.type)
      if (index >= 0) {
        const field = this.fields[index]
        if (field.types.includes(type)) {
          return true
        }
      }
      return false
    },
    getValidations () {
      // don't emit validation error if only a single inputValue member exists,
      //  this allows the parent form to pass when the component is not used (is valuePlaceHolder).
      if (this.inputValue.length > 1 || JSON.stringify(this.inputValue[0]) !== JSON.stringify(this.valuePlaceHolder)) {
        const eachInputValue = {}
        this.inputValue.forEach((input, index) => {
          const field = this.fields.find(field => input.type && field.value === input.type)
          if (field) {
            eachInputValue[field.value] = {}
            if ('validators' in field) { // has vuelidate validations
              if ('type' in field.validators) {
                eachInputValue[field.value].type = field.validators.type
              }
              if ('value' in field.validators) {
                eachInputValue[field.value].value = field.validators.value
              }
            } else if (field && field.value) {
              // no validations
              eachInputValue[field.value] = {} // ignore
            } else {
              // 1 or more undefined field(s)
              eachInputValue[null] = {} // ignore
            }
          } else {
            // field |type| is null (placeHolder)
            eachInputValue[null] = {
              type: { [this.$i18n.t('Type required.')]: required }
            }
          }
        })
        Object.freeze(eachInputValue)
        if (eachInputValue !== {}) {
          // use functional validations
          // https://github.com/monterail/vuelidate/issues/166#issuecomment-319924309
          return { ...this.inputValue.map(input => eachInputValue[(input.type) ? input.type : null] || {/* empty */}) }
        }
      }
      return {}
    },
    getTypeValidation (index) {
      if (this.validation && index in this.validation && 'type' in this.validation[index]) {
        return this.validation[index].type
      }
      return {}
    },
    getTypeInvalidFeedback (index) {
      let feedback = []
      if (this.validation && index in this.validation) {
        const validation = this.validation[index] /* use external vuelidate $v model */
        if (validation.type) {
          const validationModel = validation.type
          if (validationModel) {
            Object.entries(validationModel.$params).forEach(([key, value]) => {
              if (validationModel[key] === false) {
                feedback.push(key.trim())
              }
            })
          }
        }
      }
      return feedback.join('<br/>')
    },
    getValueValidation (index) {
      if (this.validation && index in this.validation && 'value' in this.validation[index]) {
        return this.validation[index].value
      }
      return {}
    },
    getValueInvalidFeedback (index) {
      let feedback = []
      if (this.validation && index in this.validation) {
        const validation = this.validation[index] /* use external vuelidate $v model */
        if (validation.value) {
          const validationModel = validation.value
          if (validationModel) {
            Object.entries(validationModel.$params).forEach(([key, value]) => {
              if (validationModel[key] === false) {
                feedback.push(key.trim())
              }
            })
          }
        }
      }
      return feedback.join('<br/>')
    },
    getMoments (index) {
      const field = this.fields.find(field => field.value === this.inputValue[index].type)
      if (field && 'moments' in field) {
        return field.moments
      }
      return null
    },
    emitExternalValidations () {
      // debounce to avoid emit storm,
      // delay to allow internal inputValue to update before building external validations
      if (this.emitExternalValidationsTimeout) clearTimeout(this.emitExternalValidationsTimeout)
      // don't emit on |drag|, fixes .is-invalid flicker on internal components shortly after drag @end
      if (this.drag) return
      this.emitExternalValidationsTimeout = setTimeout(() => {
        this.$emit('validations', this.getValidations())
        if (this.validation && this.validation.$dirty) {
          this.$nextTick(() => {
            this.validation.$touch()
          })
        }
        this.$nextTick(() => {
          // force DOM update
          this.$forceUpdate()
        })
      }, 100)
    }
  },
  mounted () {
    this.emitExternalValidations()
  },
  beforeDestroy () {
    if (this.emitExternalValidationsTimeout) {
      clearTimeout(this.emitExternalValidationsTimeout)
    }
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
    border: $input-border-width solid transparent;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;
  }
  .col-form-label {
    // Align the label with the text of the first action
    padding-top: calc(#{$input-padding-y + $spacer * .25} + #{$input-border-width * 3});
    line-height: auto;
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
      border-bottom: $input-border-width solid $input-focus-bg;
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
