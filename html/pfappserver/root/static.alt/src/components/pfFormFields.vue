<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-fields" :class="{ 'mb-0': !columnLabel }">
    <b-input-group class="pf-form-fields-input-group py-1">
      <draggable
        v-model="inputValue"
        :options="{handle: '.draghandle', dragClass: 'dragclass'}"
        class="container-fluid px-0"
        @start="onDragStart"
        @end="onDragEnd"
      >
        <b-container v-for="(_, index) in inputValue" :key="key"
          class="mx-0 px-1"
          @mouseleave="onMouseLeave()"
        >
        <component
          v-model="inputValue[index]"
          v-bind="field.attrs"
          :key="index"
          :is="field.component"
          :validation="getVuelidateModel(index)"
          :ref="'component-' + index"
          @validations="setExternalValidations(index, $event)"
          @mouseenter="onMouseEnter(index)"
          @mousemove="onMouseEnter(index)"
          no-gutter
        >
          <template slot="prepend">
            <div class="draghandle" v-if="sortable && hover === index && inputValue.length > 1">
              <icon name="th" v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"></icon>
            </div>
            <div v-else>
              {{ index + 1 }} {{field.key}}
            </div>
          </template>
          <template slot="append">
            <icon name="minus-circle" v-if="inputValue.length > 1"
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
    validation: {
      type: Object,
      default: () => { return {} }
    },
    sortable: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      externalValidations: null,
      hover: null,
      drag: false,
      key: Math.floor(Math.random() * 1E6) // used to force redraw when components resorted (draggable)
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
    getVuelidateModel (index) {
      let model = {}
      if (this.validation && Object.keys(this.validation).length > 0) {
        if (index in this.validation) model = this.validation[index]
        if ('$each' in this.validation && index in this.validation.$each) model = this.validation.$each[index]
      }
      return model
    },
    setExternalValidations (index, validations) {
      const externalValidations = { [index]: validations }
      this.externalValidations = { ...this.externalValidations, ...externalValidations } // deep merge
      this.emitExternalValidations()
    },
    getExternalValidations () {
      return this.externalValidations
    },
    emitExternalValidations () {
      this.$emit('validations', this.getExternalValidations())
    },
    onDragStart (event) {
      this.drag = true
      this.hover = null
    },
    onDragEnd (event) {
      this.drag = false
      this.forceUpdate()
    },
    onMouseEnter (index) {
      if (this.drag) return
      this.hover = index
    },
    onMouseLeave () {
      this.hover = null
    },
    forceUpdate () {
      this.key = Math.floor(Math.random() * 1E6) // update component(s) (https://vuejs.org/v2/api/#key)
      this.$nextTick(() => {
        if (this.validation && this.validation.$dirty) {
          this.validation.$touch() // update vuelidate model
        }
      })
    },
    rowAdd (index, clone = this.ctrlKey) {
      let inputValue = this.inputValue
      let newRow = (clone && (index - 1) in inputValue)
        ? JSON.parse(JSON.stringify(inputValue[index - 1])) // clone, dereference
        : null // use placeholder
      // push placeholder into middle of array
      this.inputValue = [...inputValue.slice(0, index), newRow, ...inputValue.slice(index)]
      this.forceUpdate()
      // focus the type element in new row
      if (!clone) { // focusing pfFormChosen steals ctrlKey's onkeyup event
        this.$nextTick(() => { // wait until DOM updates with new row
          this.focus('component-' + index)
        })
      }
    },
    rowDel (index, deleteAll = this.ctrlKey) {
      if (deleteAll) {
        for (let i = this.inputValue.length - 1; i >= 0; i--) { // delete all, bottom-up
          this.$delete(this.inputValue, i)
          this.$delete(this.externalValidations, i)
        }
        this.rowAdd(0) // add an empty row
      } else {
        const length = Object.keys(this.externalValidations).length
        for (let i = index; i < length; i++) {
          if (i < length - 1) {
            // shift down (i + 1) to (i)
            this.externalValidations[i] = this.externalValidations[i + 1]
          } else {
            // delete (i)
            this.$delete(this.externalValidations, i)
          }
        }
        // changes to inputValue are not immediately available,
        //   so we compare before we modify to avoid race-condition
        if (this.inputValue.length === 1) {
          this.inputValue.splice(index, 1) // delete 1 row
          this.rowAdd(0)
        } else {
          this.inputValue.splice(index, 1) // delete 1 row
        }
      }
      this.forceUpdate()
    },
    focus (ref) {
      if (ref in this.$refs) {
        let component = this.$refs[ref][0]
        if ('focus' in component) {
          component.focus() // defer
        }
      }
    }
  },
  watch: {
    validation (a, b) {
      // refresh vuelidate model if $dirty
      if (a.$dirty) a.$touch()
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
    border: 1px solid $input-focus-bg;
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
