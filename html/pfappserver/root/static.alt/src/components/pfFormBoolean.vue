<template>
  <div class="pf-form-boolean" :class="{ 'root': isRoot, 'highlight': highlight }"
    :draggable="!isRoot"
    @dragstart.stop="$emit('drag-start', $event)"
    @dragend.stop="$emit('drag-end', $event)"
    @dragover.stop="$emit('drag-over', $event)"
    @drop.stop="dragDrop($event)"
  >

    <div v-if="hasValues" class="pf-form-boolean-op"
      @mouseover.stop.prevent="highlight = (sourceIndex !== false) ? false : true"
      @mouseout="highlight = false"
    >
      <span class="m-0">
        <span v-if="!isRoot" class="drag-handle" :class="{ 'text-secondary': disabled }">
          <icon name="grip-vertical"></icon>
        </span>
        <slot name="op" v-bind="{ op, formStoreName, formNamespace, disabled }"></slot>
      </span>
      <span class="menu">
        <b-dropdown v-if="!isRoot || !isBoolean"
          no-caret lazy right variant="transparent" ref="menu" :disabled="disabled">
          <template v-slot:button-content>
            <icon name="cog"></icon>
          </template>
          <b-dropdown-group v-if="!isRoot">
            <b-dropdown-item @click="$emit('clone-operator'); highlight = false;">
              <icon name="clone" class="mr-1"></icon> {{ $t('Clone') }}
            </b-dropdown-item>
            <b-dropdown-item @click="$emit('delete-operator'); highlight = false;">
              <icon name="trash-alt" class="mr-1"></icon>  {{ $t('Delete') }}
            </b-dropdown-item>
          </b-dropdown-group>
          <b-dropdown-group v-if="!isBoolean">
            <b-dropdown-item @click="addOperator(values.length + 1); highlight = false;">
              <icon name="grip-horizontal" class="mr-1"></icon> {{ $t('Add Operator') }}
            </b-dropdown-item>
            <b-dropdown-item @click="addValue(values.length + 1); highlight = false;">
              <icon name="ellipsis-h" class="mr-1"></icon> {{ $t('Add Value') }}
            </b-dropdown-item>
            <b-dropdown-item @click="truncate(); highlight = false;">
              <icon name="cut" class="mr-1"></icon> {{ $t('Truncate') }}
            </b-dropdown-item>
          </b-dropdown-group>
        </b-dropdown>
      </span>
    </div>

    <div v-if="hasValues && !isBoolean" class="pf-form-boolean-values"
      @mousemove="highlight = false"
      @dragover.stop="dragOver(0, $event)"
    >
      <template v-for="(value, index) in valuesPlusOne">

        <!-- drag/drop placeholder -->
        <pf-form-boolean v-if="index === targetIndex" :key="'placeholder-' + index" :isRoot="false" class="drag-target" :disabled="disabled"
          v-model="bus.value" :formStoreName="bus.formStoreName" :formNamespace="bus.formNamespace"
          @drag-over="dragOver(index, $event)"
        >
          <!-- proxy `op` slot -->
          <template v-slot:op="{ op, formStoreName, formNamespace, disabled }">
            <slot name="op" v-bind="{ op, formStoreName, formNamespace, disabled }"></slot>
          </template>
          <!-- proxy `value` slot -->
          <template v-slot:value="{ value, formStoreName, formNamespace, disabled }">
            <slot name="value" v-bind="{ value, formStoreName, formNamespace, disabled }"></slot>
          </template>
        </pf-form-boolean>

        <!-- recurse -->
        <pf-form-boolean v-if="value" v-bind="attrs(index)" :key="index" :isRoot="false" :class="{ 'drag-source': index === sourceIndex }" :disabled="disabled"
          @add-operator="addOperator(index)"
          @clone-operator="cloneOperator(index)"
          @delete-operator="deleteOperator(index)"
          @add-value="addValue(index)"
          @clone-value="cloneValue(index)"
          @delete-value="deleteValue(index)"

          @drag-start="dragStart(index, $event)"
          @drag-over="dragOver(index, $event)"
          @drag-end="dragEnd(index, $event)"
        >
          <!-- proxy `op` slot -->
          <template v-slot:op="{ op, formStoreName, formNamespace, disabled }">
            <slot name="op" v-bind="{ op, formStoreName, formNamespace, disabled }"></slot>
          </template>
          <!-- proxy `value` slot -->
          <template v-slot:value="{ value, formStoreName, formNamespace, disabled }">
            <slot name="value" v-bind="{ value, formStoreName, formNamespace, disabled }"></slot>
          </template>
        </pf-form-boolean>
      </template>
    </div>

    <div v-else-if="!isBoolean" class="pf-form-boolean-value">
      <span class="drag-handle" :class="{ 'text-secondary': disabled }">
        <icon name="grip-vertical"></icon>
      </span>
      <slot name="value" v-bind="{ value, formStoreName, formNamespace, disabled }"></slot>
      <span class="menu">
        <b-dropdown no-caret lazy right variant="transparent" ref="menu" :disabled="disabled">
          <template v-slot:button-content>
            <icon name="cog"></icon>
          </template>
          <b-dropdown-group>
            <b-dropdown-item @click="$emit('clone-value'); highlight = false;">
              <icon name="clone" class="mr-1"></icon> {{ $t('Clone') }}
            </b-dropdown-item>
            <b-dropdown-item @click="$emit('delete-value'); highlight = false;">
              <icon name="trash-alt" class="mr-1"></icon>  {{ $t('Delete') }}
            </b-dropdown-item>
          </b-dropdown-group>
        </b-dropdown>
      </span>
    </div>

  </div>
</template>

<script>
import Vue from 'vue'
import pfMixinForm from '@/components/pfMixinForm'

/*
 *  Singleton reactive bus injected into all child components
 */
const busRef = Vue.observable({
  source: false,
  sourceElement: false,
  target: false,
  value: null,
  formStoreName: null,
  formNamespace: null,
  commit: () => {}
})

/*
 *  CSS flex-box layout can stack elements either vertical (above/below) or horizontal (left/right)
 *  2 drop zones accomodate both layouts:
 *    previous: within triangle @top-left (returns true)
 *    next: within triangle @bottom-right (returns false)
 */
const isMouseOverNext = (event) => {
  const { target, x, y } = event
  const { width, height, top, left } = target.closest('.pf-form-boolean').getBoundingClientRect()
  const ar = width / height
  const dx = x - left
  const dy = height - dx / ar
  return (y - top > dy) // false: previous, true: next
}

export default {
  name: 'pf-form-boolean',
  mixins: [
    pfMixinForm
  ],
  provide () {
    return (this.isRoot) ? { busRef } : {/* noop */}
  },
  inject: {
    bus: {
      default: busRef
    }
  },
  data () {
    return {
      sourceIndex: false, // drag @source
      targetIndex: false, // drag @target
      highlight: false // menu
    }
  },
  props: {
    value: {
      type: Object,
      default: null
    },
    isRoot: {
      type: Boolean,
      default: true
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    inputValue: {
      get () {
        if (this.formStoreName && this.formNamespace) {
          return this.formStoreValue // use FormStore
        } else {
          return this.value // use native (v-model)
        }
      },
      set (newValue = null) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    hasValues () {
      const { inputValue: { values } = {} } = this
      return values && values.constructor === Array
    },
    op () {
      const { inputValue: { op } = {} } = this
      return op || null
    },
    isBoolean () {
      const { inputValue: { op } = {} } = this
      return ['true'].includes(op)
    },
    values () {
      const { inputValue: { values = [] } = {} } = this
      return values
    },
    valuesPlusOne () {
      let { values } = this
      return [ ...((values.constructor === Array) ? values : []), null ] // +1 stub for extra placeholder @ end
    }
  },
  methods: {
    attrs (index) {
      const { inputValue: { values: { [index]: value } = {} } = {}, formStoreName, formNamespace } = this
      return { value, formStoreName, formNamespace: `${formNamespace}.values.${index}` }
    },
    addValue (index, newValue = {}) {
      let { inputValue: { values } = {} } = this
      this.inputValue.values = [...values.slice(0, index), newValue, ...values.slice(index)]
    },
    cloneValue (index) {
      const { inputValue: { values } = {} } = this
      let newValue
      try { // dereference
        newValue = JSON.parse(JSON.stringify(values[index]))
      } catch (err) {
        newValue = (values[index] && Object.keys(values[index]).length > 0)
          ? Object.assign({}, values[index])
          : null
      }
      this.inputValue.values = [...values.slice(0, index + 1), newValue, ...values.slice(index + 1)]
    },
    deleteValue (index) {
      const { inputValue: { values } = {} } = this
      if (values && index in values) {
        this.inputValue.values = [...values.slice(0, index), ...values.slice(index + 1)]
      }
    },
    addOperator (index, op = 'and') {
      const { inputValue: { values } = {} } = this
      const newOp = { op, values: [] }
      this.inputValue.values = [...values.slice(0, index), newOp, ...values.slice(index)]
    },
    cloneOperator (index) {
      const { inputValue: { values } = {} } = this
      let newOp
      try { // dereference
        newOp = JSON.parse(JSON.stringify(values[index]))
      } catch (err) {
        newOp = (values[index] && Object.keys(values[index]).length > 0)
          ? Object.assign({}, values[index])
          : null
      }
      this.inputValue.values = [...values.slice(0, index + 1), newOp, ...values.slice(index + 1)]
    },
    deleteOperator (index) {
      const { inputValue: { values } = {} } = this
      if (index in values) {
        this.inputValue.values = [...values.slice(0, index), ...values.slice(index + 1)]
      }
    },
    truncate () {
      this.inputValue.values = []
    },
    dragStart (index, event) { // @source
      const { target: sourceElement, clientX: x, clientY: y } = event
      if (!document.elementFromPoint(x, y).closest('.drag-handle, .pf-form-boolean').classList.contains('drag-handle')) { // not a handle
        event.preventDefault() // cancel drag
        return
      }
      this.sourceIndex = index
      const { formStoreName, formNamespace, inputValue } = this
      this.$set(this.bus, 'commit', () => {})
      this.$set(this.bus, 'formStoreName', formStoreName)
      this.$set(this.bus, 'formNamespace', `${formNamespace}.values.${index}`)
      this.$set(this.bus, 'value', inputValue.values[index])
      this.$set(this.bus, 'source', this)
      this.$set(this.bus, 'sourceElement', sourceElement)
    },
    dragOver (index, event) { // @target
      if (this.disabled) return
      event.preventDefault() // always allow drop

      const isNext = isMouseOverNext(event) // determine mouse position over @target
      const targetElement = event.target.closest('.pf-form-boolean')
      if (targetElement.classList.contains('drag-target')) {
        return // ignore placeholder
      }
      if (targetElement.classList.contains('root')) {
        this.targetIndex = false
        this.$set(this.bus, 'commit', () => {})
        return // ignore root
      }
      const { bus: { sourceElement } = {} } = this
      if (sourceElement.contains(targetElement)) {
        this.targetIndex = false
        this.$set(this.bus, 'commit', () => {})
        return // ignore self, ignore children
      }
      const { previousElementSibling, nextElementSibling } = targetElement
      if (!isNext && previousElementSibling && previousElementSibling.isSameNode(sourceElement)) {
        return // ignore previous sibling
      }
      if (isNext && nextElementSibling && nextElementSibling.isSameNode(sourceElement)) {
        return // ignore next sibling
      }
      // @target is valid
      if (isNext) {
        index += 1 // shift after following
      }
      this.targetIndex = index
      this.$set(this.bus, 'target', this)
      this.$set(this.bus, 'commit', (() => {
        let sourceIndex = this.bus.source.sourceIndex
        const value = this.bus.source.inputValue.values[sourceIndex]
        this.bus.target.addValue(this.bus.target.targetIndex, value)

        let targetIndex = this.bus.target.targetIndex
        if (this.bus.source === this.bus.target && targetIndex < sourceIndex) {
          sourceIndex += 1
        }
        this.bus.source.deleteValue(sourceIndex)
      }))
    },
    dragDrop () { // @anywhere
      this.bus.commit()
    },
    dragEnd () { // @source
      if (this.bus.source) {
        this.$set(this.bus.source, 'sourceIndex', false)
      }
      if (this.bus.target) {
        this.$set(this.bus.target, 'targetIndex', false)
      }
    }
  },
  watch: {
    isBoolean: {
      handler: function (a) {
        if (a) { // is a pure boolean (true) with no values
          this.truncate() // empty values
        }
      }
    }
  }
}
</script>

<style lang="scss">
  .pf-form-boolean {
    display: flex;
    flex-wrap: wrap;
    justify-content: flex-start;
    border-radius: .5rem;
    transition: background-color .3s ease-out,
      border-color .3s ease-out;

    & .pf-form-boolean {
      border-radius: .25rem;
      border-color: var(--light);
      border-style: solid;
      border-width: 0px 1px 1px 0px;
    }

    &.highlight {
      border-color: var(--primary);
      background-color: var(--primary);
      color: var(--light);
      .invalid-feedback,
      .menu .dropdown > .btn {
        color: var(--light);
      }
      .form-control.is-invalid,
      .pf-form-chosen.is-invalid .multiselect__tags,
      .pf-form-boolean-values {
        border-color: var(--light);
      }
    }

    .pf-form-boolean-op,
    .pf-form-boolean-values,
    .pf-form-boolean-value {
      display: flex;
      align-items: stretch;
      user-select: none; /* disable user selection on drag */
      input, select, textarea {
        user-select: initial; /* override user selection on input elements */
      }
    }

    .pf-form-boolean-op {
      display: flex;
      align-self: center;
      flex-shrink: 0;
      flex-wrap: nowrap;
      margin-right: -8.33333%;
      min-width: 8.33333%;
      padding: 0 .5rem 0 0 !important;
      & > * {
        display: flex;
        align-self: center;
      }
    }

    .pf-form-boolean-values {
      flex-wrap: wrap;
      justify-content: flex-start;
      margin-left: 8.33333%;
      margin-right: .25rem;

      /* curly brackets */
      border-color: var(--secondary);
      border-radius: .5rem;
      border-style: solid;
      border-width: 0 .25rem;
      padding: 0 .25rem;
    }

    .pf-form-boolean-value {
      display: flex;
      flex-wrap: nowrap;
    }

    /* add/del menu */
    .menu {
      align-self: center;
      cursor: pointer;
      flex-shrink: 0;
      .dropdown > .btn { // menu dropdown
        padding: .375rem 0;
        .fa-icon {
          height: 14px !important;
        }
      }
      & > * {
        margin: 0 0 0 .25rem;
        &:hover {
          color: var(--primary);
        }
      }
    }

    .drag-handle {
      align-self: center;
      cursor: grab;
      flex-shrink: 0;
      margin: 0 .25rem;
    }

    &.drag-source {
      opacity: .5;
    }

    &.drag-target {
      border-color: var(--primary);
      background-color: var(--primary);
      svg {
        visibility: hidden;
      }
      .pf-form-boolean-values {
        border-color: var(--light);
      }
    }
  }
</style>
