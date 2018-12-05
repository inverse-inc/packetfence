<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-configuration-rules" :class="{ 'is-focus': drag, 'mb-0': !columnLabel }"
    >
    <b-input-group class="pf-form-configuration-rules-input-group">
      <!--
         - Vacuum-up label click event.
         - See: https://github.com/bootstrap-vue/bootstrap-vue/issues/2063
      -->
      <input type="text" name="vaccum" :value="null" style="position: absolute; width: 1px; height: 1px; padding: 0px; border: 0px; visibility: hidden;" />
      <b-container fluid class="px-0"
        v-bind="$attrs"
        @mouseleave="onMouseLeave()"
      >
        <b-button v-if="!inputValue || inputValue.length === 0"
          @click="rowAdd(0)" variant="outline-secondary">{{ $t('Add Rule - New (  )') }}</b-button>

        <draggable v-else
          v-model="inputValue"
          :options="{handle: '.drag-handle', dragClass: 'dragclass'}"
          @start="onDragStart"
          @end="onDragEnd"
        >
          <b-form-group v-for="(value, index) in inputValue" :key="index" class="mb-0">
            <b-form-row
              class="text-secondary align-items-center"
              align-v="center"
              @mouseenter="onMouseEnter(index)"
              @mousemove="onMouseEnter(index)"
              no-gutter
            >
              <b-col col v-if="sortable && hover === index && inputValue.length > 1" class="drag-handle text-center">
                <icon name="th" v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"></icon>
              </b-col>
              <b-col col v-else class="drag-index text-center">
                <b-badge variant="light">{{ index + 1 }}</b-badge>
              </b-col>
              <b-col cols="10"
                class="collapse-handle py-2"
                :class="(invalidRule(index)) ? 'text-danger' : 'text-primary'"
                v-b-toggle="uuidStr('collapse' + index)" @click.prevent="clickRule(uuidStr('collapse' + index), $event)"
              >
                <icon v-if="isRuleVisible(uuidStr('collapse' + index))" name="chevron-circle-down" :class="['mr-3', { 'text-primary': ctrlKey, 'text-dark': !ctrlKey }]"></icon>
                <icon v-else name="chevron-circle-right" :class="['mr-3', { 'text-primary': ctrlKey, 'text-dark': !ctrlKey }]"></icon>
                <span>Rule - {{ getValue(index, 'id') || 'New' }} ( {{ getValue(index, 'description') }} )</span>
              </b-col>
              <b-col col class="text-center text-nowrap">
                <icon name="minus-circle"
                  :class="['cursor-pointer mx-1', { 'text-primary': ctrlKey, 'text-dark': !ctrlKey }]"
                  v-b-tooltip.hover.left.d300
                  :title="$t((ctrlKey) ? 'Delete All Rules' : 'Delete Rule')"
                  @click.native.stop.prevent="rowDel(index)"></icon>
                <icon name="plus-circle"
                  :class="['cursor-pointer mx-1', { 'text-primary': ctrlKey, 'text-dark': !ctrlKey }]"
                  v-b-tooltip.hover.left.d300
                  :title="$t((ctrlKey) ? 'Clone Rule' : 'Add Rule')"
                  @click.native.stop.prevent="rowAdd(index + 1)"></icon>
              </b-col>
            </b-form-row>
            <b-collapse :id="uuidStr('collapse' + index)" :ref="uuidStr('collapse')" class="mt-2" :visible="true">
              <b-form-row
                class="text-secondary align-items-center"
                align-v="center"
                @mouseenter="onMouseEnter(index)"
                @mousemove="onMouseEnter(index)"
                no-gutter
              >
                <b-col cols="12" class="text-left py-0 px-2" align-self="start">

                  <pf-form-input :column-label="$t('Name')" label-cols="2"
                    :ref="'name-' + index"
                    :value="getValue(index, 'id')"
                    :vuelidate="getVuelidateModel(index, 'id')"
                    @input="setValue(index, 'id', $event)"
                    class="mb-1 mr-2"
                  ></pf-form-input>
                  <pf-form-input :column-label="$t('Description')" label-cols="2"
                    :value="getValue(index, 'description')"
                    :vuelidate="getVuelidateModel(index, 'description')"
                    @input="setValue(index, 'description', $event)"
                    class="mb-1 mr-2"
                  ></pf-form-input>
                  <pf-form-chosen :column-label="$t('Matches')" label-cols="2"
                    label="text"
                    track-by="value"
                    :placeholder="typeLabel"
                    :options="[
                      { value: 'all', text: $i18n.t('All') },
                      { value: 'any', text: $i18n.t('Any') }
                    ]"
                    :vuelidate="getVuelidateModel(index, 'match')"
                    :value="getValue(index, 'match')"
                    @input="setValue(index, 'match', $event)"
                    collapse-object
                  ></pf-form-chosen>
                  <pf-form-conditions :column-label="$t('Conditions')" label-cols="2"
                    :fields="conditions || []"
                    :type-label="$t('Select condition type')"
                    :value-label="$t('Select condition value')"
                    :vuelidate="getVuelidateModel(index, 'conditions')"
                    :invalid-feedback="[
                      { [$t('Conditions(s) contain one or more errors.')]: !(getVuelidateModel(index, 'conditions') && getVuelidateModel(index, 'conditions').anyError) }
                    ]"
                    :value="getValue(index, 'conditions')"
                    @input="setValue(index, 'conditions', $event)"
                    @validations="setComponentValidations(index, 'actions', $event)"
                    class="mb-1 mr-2"
                    sortable
                  ></pf-form-conditions>
                  <pf-form-actions :column-label="$t('Actions')" label-cols="2"
                    :fields="actions || []"
                    :type-label="$t('Select action type')"
                    :value-label="$t('Select action value')"
                    :vuelidate="getVuelidateModel(index, 'actions')"
                    :invalid-feedback="[
                      { [$t('Action(s) contain one or more errors.')]: !(getVuelidateModel(index, 'actions') && getVuelidateModel(index, 'actions').anyError) }
                    ]"
                    :value="getValue(index, 'actions')"
                    @input="setValue(index, 'actions', $event)"
                    @validations="setComponentValidations(index, 'actions', $event)"
                    class="mb-1 mr-2"
                    sortable
                  ></pf-form-actions>
                </b-col>
              </b-form-row>
            </b-collapse>
          </b-form-group>
        </draggable>
      </b-container>
    </b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import uuidv4 from 'uuid/v4'
import draggable from 'vuedraggable'
import pfFormActions from '@/components/pfFormActions'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormConditions from '@/components/pfFormConditions'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'
import pfMixinValidation from '@/components/pfMixinValidation'
import {
  pfFieldType as fieldType
} from '@/globals/pfField'
import {
  pfConfigurationActions as actionFields
} from '@/globals/pfConfiguration'

export default {
  name: 'pf-form-configuration-rules',
  mixins: [
    pfMixinCtrlKey,
    pfMixinValidation
  ],
  components: {
    draggable,
    pfFormActions,
    pfFormChosen,
    pfFormConditions,
    pfFormDatetime,
    pfFormInput,
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
    actions: {
      type: Array,
      default: null
    },
    conditions: {
      type: Array,
      default: null
    },
    vuelidate: {
      type: Object
    },
    sortable: {
      type: Boolean,
      default: true
    },
    typeLabel: {
      type: String
    },
    valueLabel: {
      type: String
    },
    collapse: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      uuid:                     uuidv4(), // unique id for multiple instances of this component
      rulePlaceHolder:          { id: null, description: null, match: 'all', conditions: null, actions: [{ type: 'set_role', value: 'default' }] },
      hover:                    null,
      drag:                     false,
      actionFields:             actionFields,
      visibleRules:             [],
      componentValidations:     {}, // will be overloaded with data from the pfConfigActions and pfConfigConditions
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
        return (this.value) ? this.value : []
      },
      set (newValue) {
        this.$emit('input', newValue)
        this.emitExternalValidations()
      }
    }
  },
  methods: {
    uuidStr (section) {
      return (section || 'default') + '-' + this.uuid
    },
    getValue (index, key) {
      if (this.inputValue.length >= index && key in this.inputValue[index]) {
        return this.inputValue[index][key]
      }
      return null
    },
    setValue (index, key, value) {
      if (this.inputValue.length >= index && key in this.inputValue[index]) {
        this.$set(this.inputValue[index], key, value)
      }
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
    setComponentValidations (index, key, validations) {
      if (!(index in this.componentValidations)) {
        this.componentValidations[index] = {}
      }
      this.componentValidations[index][key] = validations
      this.emitExternalValidations()
    },
    getVuelidateModel (index, key) {
      if (this.vuelidate) {
        if (index in this.vuelidate) {
          if (key in this.vuelidate[index]) {
            return this.vuelidate[index][key]
          }
        }
        if ('$each' in this.vuelidate) {
          if (index in this.vuelidate.$each) {
            if (key in this.vuelidate.$each[index]) {
              return this.vuelidate.$each[index][key]
            }
          }
        }
      }
      return null
    },
    rowAdd (index, clone = this.ctrlKey) {
      // dereference inputValue
      let inputValue = JSON.parse(JSON.stringify(this.inputValue))
      let rulePlaceHolder = (clone && (index - 1) in inputValue)
        ? JSON.parse(JSON.stringify(inputValue[index - 1])) // clone
        : JSON.parse(JSON.stringify(this.rulePlaceHolder)) // use placeholder, dereference
      // push placeholder into middle of array
      this.inputValue = [...inputValue.slice(0, index), rulePlaceHolder, ...inputValue.slice(index)]
      this.emitExternalValidations()
      // focus the name element in new row
      if (!clone) { // focusing pfFormChosen steals ctrlKey's onkeyup event
        this.setFocus('name-' + index)
      }
    },
    rowDel (index, deleteAll = this.ctrlKey) {
      let inputValue = JSON.parse(JSON.stringify(this.inputValue))
      if (deleteAll) {
        inputValue = [] // delete all rows
        this.componentValidations = {} // truncate component validations
      } else {
        inputValue.splice(index, 1) // delete 1 row
        // truncate component validations
        let componentValidations = {}
        Object.keys(this.componentValidations).forEach(i => {
          switch (true) {
            case (i < index): componentValidations[i] = this.componentValidations[i]
              break
            case (i === index): // noop
              break
            case (i > index): componentValidations[i - 1] = this.componentValidations[i]
              break
          }
        })
        this.componentValidations = componentValidations
      }
      this.inputValue = inputValue
      if (this.inputValue.length === 0) {
        this.rowAdd(0)
      } else {
        this.emitExternalValidations()
      }
    },
    invalidRule (index) {
      if (this.vuelidate) {
        if (!this.vuelidate.$anyError && !this.vuelidate.$dirty) return false
        if (
          '$each' in this.vuelidate &&
          index in this.vuelidate.$each &&
          '$invalid' in this.vuelidate.$each[index] &&
          !this.vuelidate.$each[index].$invalid
        ) {
          this.vuelidate.$each[index].$touch()
          return false
        }
      }
      return true
    },
    onDragStart (event) {
      this.drag = true
      this.hover = null
      // store visible rules for onDragEnd
      this.visibleRules = this.$refs[this.uuidStr('collapse')].map(ref => ref.show)
    },
    onDragEnd (event) {
      this.drag = false
      // resort visibility
      let visibleRules = this.visibleRules
      let { oldIndex, newIndex } = event
      visibleRules = [...visibleRules.slice(0, oldIndex), ...visibleRules.slice(oldIndex + 1)]
      visibleRules = [...visibleRules.slice(0, newIndex), this.visibleRules[oldIndex], ...visibleRules.slice(newIndex)]
      this.$refs[this.uuidStr('collapse')].map((ref, index) => {
        ref.show = visibleRules[index]
      })
      this.emitExternalValidations()
    },
    onMouseEnter (index) {
      if (this.drag) return
      this.hover = index
    },
    onMouseLeave () {
      this.hover = null
    },
    getVuelidateModels () {
      return this.componentValidations
    },
    emitExternalValidations () {
      // debounce to avoid emit storm,
      // delay to allow internal inputValue to update before building external validations
      if (this.emitExternalValidationsTimeout) clearTimeout(this.emitExternalValidationsTimeout)
      // don't emit on |drag|, fixes .is-invalid flicker on internal components shortly after drag @end
      if (this.drag) return
      this.emitExternalValidationsTimeout = setTimeout(() => {
        this.$emit('validations', this.getVuelidateModels())
        this.$nextTick(() => {
          if (this.vuelidate && this.vuelidate.$dirty) {
            this.vuelidate.$touch()
          }
          // force DOM update
          this.$forceUpdate()
        })
      }, 100)
    },
    isRuleVisible (id) {
      const refs = this.$refs[this.uuidStr('collapse')]
      if (refs) {
        let collapse = refs.filter(ref => ref.$el.id === id)[0]
        if (collapse && 'show' in collapse) {
          return collapse.show
        }
      }
    },
    clickRule (id, event) {
      if (this.ctrlKey) { // [CTRL] + CLICK = toggle all
        this.$nextTick(() => {
          const show = this.isRuleVisible(id)
          this.$refs[this.uuidStr('collapse')].map(ref => { ref.show = show })
        })
      }
    }
  },
  mounted () {
    this.emitExternalValidations()
  },
  created () {
    this.$store.dispatch('config/getAdminRoles') // roles for rule > actions > set_access_level
    this.$store.dispatch('config/getRoles') // roles for rule > actions > set_role
    this.$store.dispatch('config/getTenants') // tenants for rule > actions > set_tenant_id
    this.$nextTick(() => {
      const collapsible = this.$refs[this.uuidStr('collapse')]
      if (this.collapse && collapsible && collapsible.length > 0) {
        collapsible.map(ref => { ref.show = false }) // collapse all
      }
    })
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

.pf-form-configuration-rules {
  .pf-form-configuration-rules-input-group {
    border: 1px solid $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;
  }
  &.is-focus {
    .pf-form-configuration-rules-input-group {
      border-color: $input-focus-border-color;
      box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
    }
  }
  &.is-invalid {
    .pf-form-configuration-rules-input-group {
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
.collapse-handle {
  cursor: pointer;
}
.drag-handle {
  cursor: grab;
}
.drag-index {
  font-size: 80%
}
.cursor-pointer {
  cursor: pointer;
}
</style>
