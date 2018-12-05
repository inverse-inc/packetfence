<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-fields" :class="{ 'mb-0': !columnLabel }">
    <b-input-group class="pf-form-fields-input-group">
      <!--
         - Vacuum-up label click event.
         - See: https://github.com/bootstrap-vue/bootstrap-vue/issues/2063
      -->
      <input type="text" name="vaccum" :value="null" style="position: absolute; width: 1px; height: 1px; padding: 0px; border: 0px; visibility: hidden;" />

      <b-container v-if="inputValue.length === 0"
        class="mx-0 px-0"
      >
        <b-button variant="outline-secondary" @click.stop="rowAdd()">{{ buttonLabel || $t('Add row') }}</b-button>
      </b-container>
      <draggable v-else
        v-model="inputValue"
        :options="{handle: '.draghandle', dragClass: 'dragclass'}"
        class="container-fluid px-0 py-1"
        @start="onDragStart"
        @end="onDragEnd"
      >
        <b-container
          v-for="(_, index) in inputValue" :key="uuids[index]"
          class="mx-0 px-1"
          @mouseleave="onMouseLeave()"
        >
        <component
          v-model="inputValue[index]"
          v-bind="field.attrs"
          :is="field.component"
          :key="uuids[index]"
          :vuelidate="getVuelidateModel(index)"
          :ref="'component-' + index"
          @validations="setParentValidations(index, $event)"
          @mouseenter="onMouseEnter(index)"
          @mousemove="onMouseEnter(index)"
          @siblings="onSiblings($event)"
          no-gutter
        >
          <template slot="prepend">
            <div class="draghandle" v-if="sortable && hover === index && inputValue.length > 1">
              <icon name="th" v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"></icon>
            </div>
            <div v-else>
              {{ index + 1 }}
            </div>
          </template>
          <template slot="append">
            <icon name="minus-circle"
              :class="['cursor-pointer mx-1', { 'text-primary': ctrlKey, 'text-secondary': !ctrlKey }]"
              v-b-tooltip.hover.left.d300
              :title="$t((ctrlKey) ? 'Delete All' : 'Delete Row')"
              @click.native.stop.prevent="rowDel(index)"></icon>
            <icon name="plus-circle"
              :class="['cursor-pointer mx-1', { 'text-primary': ctrlKey, 'text-secondary': !ctrlKey }]"
              v-b-tooltip.hover.left.d300 :title="$t((ctrlKey) ? 'Clone Row' : 'Add Row')"
              @click.native.stop.prevent="rowAdd(index + 1)"></icon>
          </template>
        </component>
        </b-container>
      </draggable>
    </b-input-group>
  </b-form-group>
</template>

<script>
import uuidv4 from 'uuid/v4'
import draggable from 'vuedraggable'
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-fields',
  mixins: [
    pfMixinCtrlKey,
    pfMixinValidation
  ],
  components: {
    draggable
  },
  props: {
    value: {
      type: Array,
      default: () => { return [] }
    },
    field: {
      type: Object,
      default: () => { return {} }
    },
    vuelidate: {
      type: Object,
      default: () => { return {} }
    },
    validators: {
      type: Object,
      default: () => { return {} }
    },
    sortable: {
      type: Boolean,
      default: false
    },
    buttonLabel: {
      type: String
    },
    columnLabel: {
      type: String
    },
    labelCols: {
      type: Number,
      default: 3
    }
  },
  data () {
    return {
      externalValidations: null, // validations
      hover: null, // true onmouseover
      drag: false, // true ondrag
      uuids: [] // uuid list used to manually handle DOM redraws (https://vuejs.org/v2/api/#key)
    }
  },
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    }
  },
  methods: {
    rowAdd (index = 0, clone = this.ctrlKey) {
      let inputValue = this.inputValue
      let newRow = (clone && (index - 1) in inputValue)
        ? JSON.parse(JSON.stringify(inputValue[index - 1])) // clone, dereference
        : null // use placeholder
      // push placeholder into middle of array
      this.inputValue = [...inputValue.slice(0, index), newRow, ...inputValue.slice(index)]
      this.uuids = [...this.uuids.slice(0, index), uuidv4(), ...this.uuids.slice(index)]
      // focus the type element in new row
      if (!clone) { // Bugfix: focusing pfFormChosen steals ctrlKey's onkeyup event
        this.$nextTick(() => { // wait until DOM updates with new row
          this.focus('component-' + index)
        })
      }
      this.$nextTick(() => {
        this.getChildValidations()
        this.emitLocalValidationsToParent()
        this.forceUpdate()
      })
    },
    rowDel (index, deleteAll = this.ctrlKey) {
      if (deleteAll) {
        for (let i = this.inputValue.length - 1; i >= 0; i--) { // delete all, bottom-up
          this.$delete(this.inputValue, i)
          this.$delete(this.uuids, i)
        }
      } else {
        this.inputValue.splice(index, 1) // delete 1 row
        this.uuids.splice(index, 1)
      }
      this.externalValidations = null
      this.$nextTick(() => {
        this.getChildValidations()
        this.emitLocalValidationsToParent()
        this.forceUpdate()
      })
    },
    onDragStart (event) {
      this.drag = true
      this.hover = null
    },
    onDragEnd (event) {
      this.drag = false
      let { oldIndex, newIndex } = event // shifted, not swapped
      // shift uuids
      let uuids = this.uuids
      uuids = [...uuids.slice(0, oldIndex), ...uuids.slice(oldIndex + 1)]
      this.uuids = [...uuids.slice(0, newIndex), this.uuids[oldIndex], ...uuids.slice(newIndex)]
      // recalc validations
      for (let i = Math.min(oldIndex, newIndex); i <= Math.max(oldIndex, newIndex); i++) {
        this.getChildValidations(i)
      }
      this.forceUpdate()
    },
    onMouseEnter (index) {
      if (this.drag) return
      this.hover = index
    },
    onMouseLeave () {
      this.hover = null
    },
    /**
     * Used by child component to perform function calls on its siblings, including itself
     **/
    onSiblings ([func, ...args]) {
      this.inputValue.forEach((_, index) => {
        if (('component-' + index) in this.$refs) {
          let ref = this.$refs['component-' + index][0]
          if (func in ref && typeof ref[func] === 'function') {
            ref[func](args)
          }
        }
      })
    },
    forceUpdate () {
      this.$nextTick(() => {
        if (this.vuelidate && this.vuelidate.$dirty) {
          this.vuelidate.$touch() // update vuelidate model
        }
        this.$forceUpdate()
      })
    },
    focus (ref) {
      if (ref in this.$refs) {
        let component = this.$refs[ref][0]
        if (component && 'focus' in component) {
          component.focus() // defer
        }
      }
    },
    getVuelidateModel (index) {
      let model = {}
      if (this.vuelidate && Object.keys(this.vuelidate).length > 0) {
        if (index in this.vuelidate) model = this.vuelidate[index]
        if ('$each' in this.vuelidate && index in this.vuelidate.$each) {
          model = { ...model, ...this.vuelidate.$each[index] }
        }
      }
      return model
    },
    getFieldValidators () {
      let model = {}
      if ('validators' in this.field) {
        model = this.field.validators
      }
      return model
    },
    /**
     * Using refs, force child component(s) to emit its validations
     **/
    getChildValidations (index = null) {
      if (index === null) { // get all
        this.inputValue.forEach((_, index) => {
          this.getChildValidations(index)
        })
      } else { // get index
        if (('component-' + index) in this.$refs) {
          let ref = this.$refs['component-' + index][0]
          if ('emitLocalValidationsToParent' in ref) {
            ref.emitLocalValidationsToParent(index)
          }
        }
      }
    },
    getParentValidations () {
      return this.externalValidations
    },
    setParentValidations (index, validations) {
      const externalValidations = { [index]: validations }
      this.externalValidations = { ...this.externalValidations, ...externalValidations }
      this.emitLocalValidationsToParent()
    },
    emitLocalValidationsToParent () {
      this.$emit('validations', { ...this.getFieldValidators(), ...this.getParentValidations() })
    }
  },
  watch: {
    vuelidate (a, b) {
      // refresh vuelidate model if $dirty
      if (a.$dirty) {
        this.$nextTick(() => {
          this.vuelidate.$touch()
        })
      }
    }
  },
  created () {
    // initial uuid setup
    this.inputValue.forEach((_, index) => {
      this.uuids[index] = uuidv4()
    })
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/border-radius";
@import "../../node_modules/bootstrap/scss/mixins/transition";
@import "../styles/variables";

.pf-form-fields {
  .pf-form-fields-input-group {
    border: 1px solid $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;
  }
  .col-form-label {
    // Align the label with the text of the first action
    padding-top: calc(#{$input-padding-y} + #{$input-border-width});
    line-height: auto;
  }
  &.is-focus {
    .pf-form-fields-input-group {
      border-color: $input-focus-border-color;
      box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
    }
  }
  &.is-invalid {
    .pf-form-fields-input-group {
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
.dragclass {
  padding-top: .25rem !important;
  padding-bottom: .0625rem !important;
  background-color: $primary !important;
  path, /* svg icons */
  .invalid-feedback {
    color: $white
  }
}
.cursor-pointer {
  cursor: pointer;
}
</style>
