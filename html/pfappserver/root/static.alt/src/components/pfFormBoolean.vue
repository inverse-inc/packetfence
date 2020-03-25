<template>
  <div class="pf-form-boolean" :class="{ 'root': isRoot, 'highlight': highlight }"
    :draggable="!isRoot"
    @dragstart.stop="$emit('dragStart', $event)"
    @dragend.stop="$emit('dragEnd', $event)"
    @dragover.stop="$emit('dragOver', $event)"
    @drop.stop="dragDrop($event)"
  >

    <div v-if="hasValues" class="pf-form-boolean-op"
      @mouseover.stop.prevent="highlight = (sourceIndex !== false) ? false : true"
      @mouseout="highlight = false"
    >
      <span class="m-0">
        <span v-if="!isRoot" class="drag-handle" :class="{ 'text-secondary': disabled }">
          <icon name="grip-vertical" :class="{ 'text-primary': actionKey }"></icon>
        </span>
        <slot name="op" v-bind="{ op, formStoreName, formNamespace, disabled }"></slot>
      </span>
      <span class="menu"
        @mouseover="actionKey && $refs.menu.show(true)"
      >
        <b-dropdown no-caret lazy right variant="transparent" ref="menu" :disabled="disabled">
          <template v-slot:button-content>
            <icon name="cog" :class="{ 'text-primary': actionKey }"></icon>
          </template>
          <b-dropdown-group v-if="!isRoot">
            <b-dropdown-item @click="$emit('cloneOperator'); highlight = false; (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="clone" class="mr-1"></icon> {{ $t('Clone') }}
            </b-dropdown-item>
            <b-dropdown-item @click="$emit('deleteOperator'); highlight = false;">
              <icon name="trash-alt" class="mr-1"></icon>  {{ $t('Delete') }}
            </b-dropdown-item>
          </b-dropdown-group>
          <b-dropdown-group>
            <b-dropdown-item @click="addOperator(values.length + 1); highlight = false; (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="grip-horizontal" class="mr-1"></icon> {{ $t('Add Operator') }}
            </b-dropdown-item>
            <b-dropdown-item @click="addValue(values.length + 1); highlight = false; (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="ellipsis-h" class="mr-1"></icon> {{ $t('Add Value') }}
            </b-dropdown-item>
            <b-dropdown-item @click="truncate(); highlight = false; (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="cut" class="mr-1"></icon> {{ $t('Truncate') }}
            </b-dropdown-item>
          </b-dropdown-group>
        </b-dropdown>
      </span>
    </div>

    <div v-if="hasValues" class="pf-form-boolean-values"
      @mousemove="highlight = false"
      @dragover.stop="dragOver(0, $event)"
    >
      <template v-for="(value, index) in valuesPlusOne">

        <!-- drag/drop placeholder -->
        <pf-form-boolean v-if="index === targetIndex" :key="'placeholder-' + index" :isRoot="false" class="drag-target" :disabled="disabled"
          v-model="dataBus.data.value" :formStoreName="dataBus.data.formStoreName" :formNamespace="dataBus.data.formNamespace"
          @dragOver="dragOver(index, $event)"
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
        <pf-form-boolean v-if="value" v-bind="attrs(index)" :key="index" :isRoot="false" :dataBus="dataBus" :class="{ 'drag-source': index === sourceIndex }" :disabled="disabled"
          @addOperator="addOperator(index)"
          @cloneOperator="cloneOperator(index)"
          @deleteOperator="deleteOperator(index)"
          @addValue="addValue(index)"
          @cloneValue="cloneValue(index)"
          @deleteValue="deleteValue(index)"

          @dragStart="dragStart(index, $event)"
          @dragOver="dragOver(index, $event)"
          @dragEnd="dragEnd(index, $event)"
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

    <div v-else class="pf-form-boolean-value">
      <span class="drag-handle" :class="{ 'text-secondary': disabled }">
        <icon name="grip-vertical" :class="{ 'text-primary': actionKey }"></icon>
      </span>
      <slot name="value" v-bind="{ value, formStoreName, formNamespace, disabled }"></slot>
      <span class="menu"
        @mouseover.stop.prevent="actionKey && $refs.menu.show(true)"
      >
        <b-dropdown no-caret lazy right variant="transparent" ref="menu" :disabled="disabled">
          <template v-slot:button-content>
            <icon name="cog" :class="{ 'text-primary': actionKey }"></icon>
          </template>
          <b-dropdown-group>
            <b-dropdown-item @click="$emit('cloneValue'); highlight = false; (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="clone" class="mr-1"></icon> {{ $t('Clone') }}
            </b-dropdown-item>
            <b-dropdown-item @click="$emit('deleteValue'); highlight = false;">
              <icon name="trash-alt" class="mr-1"></icon>  {{ $t('Delete') }}
            </b-dropdown-item>
          </b-dropdown-group>
        </b-dropdown >
      </span>
    </div>

  </div>
</template>

<script>
import Vue from 'vue' // dataBus
import pfMixinForm from '@/components/pfMixinForm'

/*  CSS flex-box layout can stack elements either vertical (above/below) or horizontal (left/right)
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
    dataBus: { // singleton data bus shared /w all recursive children
      type: Object,
      default: new Vue({
        data () {
          return {
            data: {}
          }
        }
      })
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    inputValue: {
      get () {
        if (this.formStoreName) {
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
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    op () {
      const { inputValue: { op } = {} } = this
      return op || null
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
      let { inputValue: { values } = {}, sourceIndex } = this
      this.$set(this.inputValue, 'values', [...values.slice(0, index), newValue, ...values.slice(index)])
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
      this.$set(this.inputValue, 'values', [...values.slice(0, index + 1), newValue, ...values.slice(index + 1)])
    },
    deleteValue (index) {
      const { inputValue: { values } = {} } = this
      if (values && index in values) {
        this.$set(this.inputValue, 'values', [...values.slice(0, index), ...values.slice(index + 1)])
      }
    },
    addOperator (index, op = 'and') {
      const { inputValue: { values } = {} } = this
      const newOp = { op, values: [] }
      this.$set(this.inputValue, 'values', [...values.slice(0, index), newOp, ...values.slice(index)])
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
      this.$set(this.inputValue, 'values', [...values.slice(0, index + 1), newOp, ...values.slice(index + 1)])
    },
    deleteOperator (index) {
      const { inputValue: { values } = {} } = this
      if (index in values) {
        this.$set(this.inputValue, 'values', [...values.slice(0, index), ...values.slice(index + 1)])
      }
    },
    truncate () {
      this.$set(this.inputValue, 'values', [])
    },
    dragStart (index, event) { // @source
        const { target: sourceElement, clientX: x, clientY: y } = event
        if (!document.elementFromPoint(x, y).closest('.drag-handle, .pf-form-boolean').classList.contains('drag-handle')) { // not a handle
          event.preventDefault() // cancel drag
          return
        }
        this.sourceIndex = index
        const { actionKey: clone, formStoreName, formNamespace, value } = this
        new Promise((resolve) => {
          this.$set(this.dataBus, 'data', {
            clone,
            source: this,
            sourceElement,
            formStoreName,
            formNamespace: `${formNamespace}.values.${index}`,
            value,
            resolve
          })
        }).then(target => {
          if (!clone) {
            if (this.$el.isSameNode(target.$el)) { // same parent
              if (target.targetIndex <= this.sourceIndex) { // target is before source
                this.sourceIndex += 1 // increment index to include new value
              }
            }
            this.deleteValue(this.sourceIndex) // delete old value
          }
        }).finally(() => {
          this.dragEnd()
        })
        this.$store.dispatch('events/onKeyUp') // fix: unable to detect actionKey keyup while dragging
    },
    dragEnd () { // @source
      const { dataBus: { data: { source, target } = {} } = {} } = this
      if (source) {
        this.$set(source, 'sourceIndex', false)
      }
      if (target) {
        this.$set(target, 'targetIndex', false)
      }
    },
    dragOver (index, event) { // @target
      if (this.disabled) return
      event.preventDefault() // always allow drop
      const isNext = isMouseOverNext(event) // determine mouse position over @target
      let targetElement = event.target.closest('.pf-form-boolean')
      if (targetElement.classList.contains('drag-target')) return // ignore placeholder
      if (targetElement.classList.contains('root')) return // ignore root
      const { dataBus: { data: { clone, sourceElement, target } = {} } = {} } = this
      if (this.values.length > 0) { // has values (not empty)
        if (!clone) {
          if (sourceElement.contains(targetElement)) return // ignore self, ignore children
          const { previousElementSibling, nextElementSibling } = targetElement
          if (
            (!isNext && previousElementSibling && previousElementSibling.isSameNode(sourceElement))
            ||
            (isNext && nextElementSibling && nextElementSibling.isSameNode(sourceElement))
          ) return // ignore sibling previousElement@next and nextElement@previous
        }
        // @target is a valid drop target
        if (isNext) {
          index += 1 // shift after following
        }
      }
      if (this.targetIndex !== index) {
        if (target) {
          this.$set(target, 'targetIndex', false)
        }
        this.targetIndex = index
        this.$set(this.dataBus.data, 'target', this)
      }
    },
    dragDrop () { // @anywhere
      let { dataBus: { data: { source, source: { sourceIndex } = {}, target, target: { targetIndex } = {}, resolve } = {} } = {} } = this
      let value = JSON.parse(JSON.stringify(source.inputValue.values[sourceIndex]))
      target.addValue(targetIndex, value) // add new value
      resolve(target)
    }
  },
  watch: {
    actionKey: {
      handler: function (a) {
        if (!a) {
          this.$refs.menu.hide(true)
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
