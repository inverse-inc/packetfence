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

      <b-container v-if="!inputValue || inputValue.length === 0"
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
          class="mx-0 px-1 pf-form-field-component-container"
          @mouseleave="onMouseLeave()"
        >
        <component
          v-model="inputValue[index]"
          v-bind="field.attrs"
          :is="field.component"
          :key="uuids[index]"
          :vuelidate="getVuelidateModel(index)"
          :ref="'component-' + index"
          @validations="setChildValidations(index, $event)"
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
      validations: {}, // validations
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
      let length = this.inputValue.length
      let newRow = (clone && (index - 1) in inputValue)
        ? JSON.parse(JSON.stringify(inputValue[index - 1])) // clone, dereference
        : null // use placeholder
      // push placeholder into middle of array
      this.inputValue = [...inputValue.slice(0, index), newRow, ...inputValue.slice(index)]
      this.uuids = [...this.uuids.slice(0, index), uuidv4(), ...this.uuids.slice(index)]
      // shift up validations
      for (let i = length; i > index; i--) {
        this.validations[i] = this.validations[i - 1]
      }
      this.validations[index] = {}
      // focus the type element in new row
      if (!clone) { // Bugfix: focusing pfFormChosen steals ctrlKey's onkeyup event
        this.$nextTick(() => { // wait until DOM updates with new row
          this.focus('component-' + index)
        })
      }
      this.emitValidations()
      this.forceUpdate()
    },
    rowDel (index, deleteAll = this.ctrlKey) {
      let length = this.inputValue.length
      if (deleteAll) {
        for (let i = length - 1; i >= 0; i--) { // delete all, bottom-up
          this.$delete(this.inputValue, i)
          this.$delete(this.uuids, i)
        }
        this.validations = {}
      } else {
        this.inputValue.splice(index, 1) // delete 1 row
        this.uuids.splice(index, 1)
        // shift down validations
        for (let i = index; i < length; i++) {
          this.validations[i] = this.validations[i + 1]
        }
        this.validations[length] = {}
      }
      this.emitValidations()
      this.forceUpdate()
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
      // adjust validations
      let tmp = this.validations[oldIndex]
      if (oldIndex > newIndex) {
        // shift down (not swapped)
        for (let i = oldIndex; i > newIndex; i--) {
          this.validations[i] = this.validations[i - 1]
        }
      } else {
        // shift up (not swapped)
        for (let i = oldIndex; i < newIndex; i++) {
          this.validations[i] = this.validations[i + 1]
        }
      }
      this.validations[newIndex] = tmp
      this.emitValidations()
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
        const { $refs: { ['component-' + index]: component } } = this
        if (component) {
          const [ { [ func ]: f } ] = component
          if (typeof f === 'function') {
            f(...args)
          }
        }
      })
    },
    forceUpdate () {
      this.$nextTick(() => {
        this.$forceUpdate()
      })
    },
    focus (ref) {
      const { $refs: { [ref]: [ { focus } ] } } = this
      if (focus) focus()
    },
    getVuelidateModel (index) {
      const { vuelidate: { [index]: model } } = this
      return model || {}
    },
    setChildValidations (index, validations) {
      if (!(index in this.validations)) {
        this.validations[index] = {}
      }
      this.validations[index] = validations
      this.emitValidations()
    },
    emitValidations () {
      // build merge of local validations and child validations
      let validators = {}
      const { field: { validators: fieldValidators } } = this
      this.inputValue.map((_, index) => {
        if (index in this.validations) {
          validators[index] = { ...fieldValidators, ...this.validations[index] }
        }
      })
      this.$emit('validations', validators)
    }
  },
  created () {
    // initial uuid setup
    if (this.inputValue) {
      this.inputValue.forEach((_, index) => {
        this.uuids[index] = uuidv4()
      })
    }
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
    border: 1px solid transparent;
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
    > .form-row > [role="group"] > .pf-form-fields-input-group {
      border-color: $input-focus-border-color;
      box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
    }
  }
  &.is-invalid {
    > .form-row > [role="group"] > .pf-form-fields-input-group {
      border-color: $form-feedback-invalid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
    }
  }
  .pf-form-field-component-container {
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
  * {
    color: $white !important;
    border-color: transparent !important;
  }
  .pf-form-fields-input-group {
    border-color: transparent !important;
  }
}
.cursor-pointer {
  cursor: pointer;
}
</style>
