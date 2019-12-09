<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputAnyState"
    class="pf-form-fields" :class="{ 'mb-0': !columnLabel }">
    <template v-slot:invalid-feedback>
      {{ invalidFeedback }}
    </template>
    <b-input-group class="pf-form-fields-input-group">
      <!--
         - Vacuum-up label click event.
         - See: https://github.com/bootstrap-vue/bootstrap-vue/issues/2063
      -->
      <input type="text" name="vaccum" :value="null" style="position: absolute; width: 1px; height: 1px; padding: 0px; border: 0px; visibility: hidden;" />

      <b-container v-if="!inputValue || inputValue.length === 0"
        class="mx-0 px-0"
      >
        <b-button variant="outline-secondary" @click.stop="rowAdd()" :disabled="disabled">{{ buttonLabel || $t('Add row') }}</b-button>
        <small v-if="emptyText" class="ml-2">{{ emptyText }}</small>
      </b-container>

      <draggable v-else
        v-model="inputValue"
        :options="{handle: '.draghandle', dragClass: 'dragclass'}"
        class="container-fluid px-0"
        @start="onDragStart"
        @end="onDragEnd"
      >
        <b-container
          v-for="(_, index) in inputValue" :key="index"
          class="mx-0 px-1 pf-form-field-component-container"
          @mouseleave="onMouseLeave()"
        >
          <component :ref="'component-' + index"
            :is="field.component"
            :formStoreName="formStoreName"
            :formNamespace="`${formNamespace}.${index}`"
            v-model="inputValue[index]"
            v-bind="field.attrs"
            v-on="field.listeners"
            :key="index"
            :drag="drag"
            :disabled="disabled"
            @mouseenter="onMouseEnter(index)"
            @mousemove="onMouseEnter(index)"
            @siblings="onSiblings($event)"
            no-gutter
            class="m-1"
          >
            <template v-slot:prepend>
              <div class="draghandle" v-if="sortable && !disabled && hover === index && inputValue.length > 1">
                <icon name="th" v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"></icon>
              </div>
              <div v-else>
                {{ index + 1 }}
              </div>
            </template>
            <template v-slot:append>
              <icon name="minus-circle" v-if="canDel"
                :class="['cursor-pointer mx-1', { 'text-primary': actionKey, 'text-secondary': !actionKey }]"
                v-b-tooltip.hover.left.d300
                :title="actionKey ? $t('Delete All') : $t('Delete Row')"
                @click.native.stop.prevent="rowDel(index)"></icon>
              <icon name="plus-circle" v-if="canAdd"
                :class="['cursor-pointer mx-1', { 'text-primary': actionKey, 'text-secondary': !actionKey }]"
                v-b-tooltip.hover.left.d300 :title="actionKey ? $t('Clone Row') : $t('Add Row')"
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
import pfMixinForm from '@/components/pfMixinForm'
import i18n from '@/utils/locale'

export default {
  name: 'pf-form-fields',
  mixins: [
    pfMixinForm
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
    sortable: {
      type: Boolean,
      default: false
    },
    emptyText: {
      type: String,
      default: null
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
    },
    minFields: {
      type: Number,
      default: 0
    },
    maxFields: {
      type: Number,
      default: 0
    },
    disabled: {
      type: Boolean,
      default: false
    },
    invalidFeedback: {
      type: String,
      default: i18n.t('One or more errors exist.')
    }
  },
  data () {
    return {
      hover: null, // true onmouseover
      drag: false // true ondrag
    }
  },
  computed: {
    inputValue: {
      get () {
        let value
        if (this.formStoreName) {
          value = this.formStoreValue // use FormStore
        } else {
          value = this.value // use native (v-model)
        }
        return value
      },
      set (newValue = null) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    canAdd () {
      return (!this.disabled && (!this.maxFields || this.maxFields > this.inputValue.length))
    },
    canDel () {
      return (!this.disabled && (!this.minFields || this.minFields < this.inputValue.length))
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    }
  },
  methods: {
    rowAdd (index = 0, clone = this.actionKey) {
      let inputValue = this.inputValue || []
      let length = inputValue.length
      let newRow = (clone && (index - 1) in inputValue)
        ? JSON.parse(JSON.stringify(inputValue[index - 1])) // clone, dereference
        : null // use placeholder
      // push placeholder into middle of array
      this.inputValue = [...inputValue.slice(0, index), newRow, ...inputValue.slice(index)]
      // focus the type element in new row
      if (!clone) { // Bugfix: focusing pfFormChosen steals actionKey's onkeyup event
        this.focus('component-' + index)
      }
    },
    rowDel (index, deleteAll = this.actionKey) {
      let length = this.inputValue.length
      if (deleteAll) {
        for (let i = length - 1; i >= 0; i--) { // delete all, bottom-up
          this.$delete(this.inputValue, i)
        }
      } else {
        this.inputValue.splice(index, 1) // delete 1 row
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
    /**
     * Used by child component to perform function calls on its siblings, including itself
     **/
    onSiblings (func, ...args) {
      this.inputValue.forEach((_, index) => {
        const { $refs: { ['component-' + index]: component } } = this
        if (component) {
          const [ { [ func ]: f } ] = component
          if (f.constructor === Function) {
            f(...args)
          }
        }
      })
    },
    focus (ref) {
      this.$nextTick(() => { // wait until DOM updates with new row
        const { $refs: { [ref]: { 0: { focus = () => {} } = {} } = {} } = {} } = this
        focus()
      })
    }
  }
}
</script>

<style lang="scss">
.pf-form-fields {
  .pf-form-fields-input-group {
    border: 1px solid transparent;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;
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
      /* TODO: Bugfix
      button.btn {
        color: $white !important;
        border: 1px solid $white !important;
        border-color: $white !important;
      }
      */
      input,
      select,
      .multiselect__single {
        color: $primary !important;
      }
      .pf-form-fields-input-group {
        border-color: transparent !important;
      }
    }
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
      margin-bottom: map-get($spacers, 1);
    }
  }
}
.cursor-pointer {
  cursor: pointer;
}
</style>
