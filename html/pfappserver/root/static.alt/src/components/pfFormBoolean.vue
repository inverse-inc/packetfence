<template>
  <div class="pf-form-boolean" :class="{ 'root': isRoot }"
    :draggable="!isRoot"
    @dragstart.stop="$emit('dragStart', $event)"
    @dragleave.stop="$emit('dragLeave', $event)"
    @dragend.stop="$emit('dragEnd', $event)"
    @dragover.stop="$emit('dragOver', $event)"
    @drop.stop="dragDrop($event)"
  >

    <div v-if="hasValues" class="pf-form-boolean-op">
      <span
        @mouseover.stop.prevent="highlight = true"
        @mouseout="highlight = false"
        class="m-0"
      >
        <span v-if="!isRoot" v-on="opListeners" class="handle">
          <icon name="grip-vertical"></icon>
        </span>
        <slot name="op" v-bind="{ op, formStoreName, formNamespace }"></slot>
      </span>
      <span class="menu"
        @mouseover="actionKey && $refs.menu.show(true)"
      >
        <b-dropdown no-caret lazy right variant="transparent" ref="menu">
          <template v-slot:button-content>
            <icon name="cog" :class="{ 'text-primary': actionKey }"></icon>
          </template>
          <b-dropdown-group v-if="!isRoot">
            <b-dropdown-header>{{ $t('Operator') }}</b-dropdown-header>
            <b-dropdown-item @click="$emit('cloneOperator'); (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="copy" class="mr-1"></icon> {{ $t('Clone') }}
            </b-dropdown-item>
            <b-dropdown-item @click="$emit('deleteOperator'); highlight = false;">
              <icon name="trash-alt" class="mr-1"></icon>  {{ $t('Delete') }}
            </b-dropdown-item>
          </b-dropdown-group>
          <b-dropdown-group>
            <b-dropdown-header>{{ $t('Collection') }}</b-dropdown-header>
            <b-dropdown-item @click="addOperator(values.length); (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="plus-circle" class="mr-1"></icon> {{ $t('Add Operator') }}
            </b-dropdown-item>
            <b-dropdown-item @click="addValue(values.length); (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="plus-circle" class="mr-1"></icon> {{ $t('Add Value') }}
            </b-dropdown-item>
            <b-dropdown-item @click="truncate(); (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="times-circle" class="mr-1"></icon> {{ $t('Truncate') }}
            </b-dropdown-item>
          </b-dropdown-group>
        </b-dropdown>
      </span>
    </div>

    <div v-if="hasValues" class="pf-form-boolean-values" :class="{ 'highlight': highlight }"
      @mousemove="highlight = false"
    >
      <template v-for="(value, index) in values">

        <!-- drag/drop placeholder -->
        <div v-if="index === drop" v-html="drag.innerHTML" :key="'$' + index">{{ drag.innerHTML }}</div>

        <!-- recurse -->
        <pf-form-boolean :key="index" v-bind="attrs(index)" :isRoot="false" :eventBus="eventBus"
          @addOperator="addOperator(index)"
          @cloneOperator="cloneOperator(index)"
          @deleteOperator="deleteOperator(index)"
          @addValue="addValue(index)"
          @cloneValue="cloneValue(index)"
          @deleteValue="deleteValue(index)"

          @dragStart="dragStart(index, $event)"
          @dragLeave="dragLeave(index, $event)"
          @dragOver="dragOver(index, $event)"
          @dragEnd="dragEnd(index, $event)"
          @dropValue="dropValue(index, $event)"
        >
          <!-- proxy `op` slot -->
          <template v-slot:op="{ op, formStoreName, formNamespace }">
            <slot name="op" v-bind="{ op, formStoreName, formNamespace }"></slot>
          </template>
          <!-- proxy `value` slot -->
          <template v-slot:value="{ value, formStoreName, formNamespace }">
            <slot name="value" v-bind="{ value, formStoreName, formNamespace }"></slot>
          </template>
        </pf-form-boolean>
      </template>
    </div>

    <div v-else class="pf-form-boolean-value">
      <span v-on="valueListeners" class="handle">
        <icon name="grip-vertical"></icon>
      </span>
      <slot name="value" v-bind="{ value, formStoreName, formNamespace }"></slot>
      <span class="menu"
        @mouseover.stop.prevent="actionKey && $refs.menu.show(true)"
      >
        <b-dropdown no-caret lazy right variant="transparent" ref="menu">
          <template v-slot:button-content>
            <icon name="cog" :class="{ 'text-primary': actionKey }"></icon>
          </template>
          <b-dropdown-group>
            <b-dropdown-header>{{ $t('Value') }}</b-dropdown-header>
            <b-dropdown-item @click="$emit('cloneValue'); (actionKey && $nextTick(() => $refs.menu.show(true)))">
              <icon name="copy" class="mr-1"></icon> {{ $t('Clone') }}
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
import Vue from 'vue' // eventBus
import pfMixinForm from '@/components/pfMixinForm'

const isBefore = (event) => {
  const { target, pageX: x, pageY: y } = event
  const { width, height, top, left } = target.getBoundingClientRect()
  /* 2 drop zones
    *  previous: within triangle from @top-left/bottom-left/top-right corners
    *  next: within triangle from @bottom-right/top-right/bottom-left corners
    */
  const ar = width / height
  const dx = x - left
  const dy = height - dx / ar
  return (y - top < dy) // true: previous, false: next
}

export default {
  name: 'pf-form-boolean',
  mixins: [
    pfMixinForm
  ],
  components: {

  },
  data () {
    return {
      drag: false,
      drop: false,
      highlight: false
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
    eventBus: { // singleton event bus for all child components
      type: Object,
      default: new Vue()
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
      return (this.inputValue && 'values' in this.inputValue)
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    op () {
      const { inputValue: { op = null } = {} } = this
      return op
    },
    values () {
      const { inputValue: { values = [] } = {} } = this
      return values
    },
    opListeners () {
      return {
        click: (event) => { console.log('click op', event); }
      }
    },
    valueListeners () {
      return {
        click: (event) => { console.log('click value', event); }
      }
    }
  },
  methods: {
    attrs (index) {
      const { inputValue: { values: { [index]: value } = {} } = {}, formStoreName, formNamespace } = this
      return { value, formStoreName, formNamespace: `${formNamespace}.values.${index}` }
    },
    addValue (index) {
      const { inputValue: { values } = {} } = this
      const newValue = undefined
      this.$set(this.inputValue, 'values', [...values.slice(0, index + 1), ...[newValue], ...values.slice(index + 1)])
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
      this.$set(this.inputValue, 'values', [...values.slice(0, index + 1), ...[newValue], ...values.slice(index + 1)])
    },
    deleteValue (index) {
      const { inputValue: { values } = {} } = this
      if (index in values) {
        this.$set(this.inputValue, 'values', [...values.slice(0, index), ...values.slice(index + 1)])
      }
    },
    addOperator (index) {
      const { inputValue: { values } = {} } = this
      let op = 'and'
      if (index in values && 'op' in values[index]) {
        op = values[index].op
      }
      const newOp = { op, values: [] }
      this.$set(this.inputValue, 'values', [...values.slice(0, index + 1), ...[newOp], ...values.slice(index + 1)])
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
      this.$set(this.inputValue, 'values', [...values.slice(0, index + 1), ...[newOp], ...values.slice(index + 1)])
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
      const { target: source, target: { parentNode: { innerHTML } = {} } = {} } = event
console.log('HTML', innerHTML)
      let { inputValue: { values: { [index]: value } = {} } = {} } = this
      try { // dereference
        value = JSON.parse(JSON.stringify(value))
      } catch (err) {
        value = (value && Object.keys(value).length > 0)
          ? Object.assign({}, value)
          : null
      }
      this.eventBus.$emit('drag', { source, value, innerHTML })
    },
    dragEnd () { // @source
      this.eventBus.$emit('drag', false)
    },
    dragLeave () { // @target
      this.drop = false
    },
    dragOver (index, event) { // @target
      const { target } = event
      const { source } = this.drag
      if (source === target) return // ignore self
      if (source.contains(target)) return // ignore child nodes
      let inspect = target
      while (!inspect.classList.contains('pf-form-boolean')) { // search parentNode's recursively
        inspect = inspect.parentNode
      }
      if (inspect.classList.contains('root')) return // ignore root's immediate children
      event.preventDefault() // allow drop
      this.drop = (isBefore(event)) ? index : index + 1 // set drop index (placeholder)
    },
    dragDrop (event) {
      if (isBefore(event)) { // previous
        this.$emit('dropValue', { ...this.drag, ...{ offset: 0 } })
      } else { // next
        this.$emit('dropValue', { ...this.drag, ...{ offset: 1 } })
      }
    },
    dropValue (index, event) {
      const { inputValue: { values } = {} } = this
      const { value, offset } = event
      this.$set(this.inputValue, 'values', [...values.slice(0, index + offset), ...[value], ...values.slice(index + offset)])
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
  },
  mounted () {
    this.eventBus.$on('drag', (data) => { // event bus listener
      this.$set(this, 'drag', data)
    })
  }
}
</script>

<style lang="scss">
  .pf-form-boolean {
    display: flex;
    flex-wrap: wrap;
    justify-content: flex-start;

    .pf-form-boolean-op,
    .pf-form-boolean-values,
    .pf-form-boolean-value {
      display: flex;
      align-items: stretch;
      user-select: none; /* disable highlighting on drag */
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
      border-radius: 0.5rem;
      border-style: solid;
      border-width: 0 .25rem;
      padding: 0 .25rem;
      &.highlight {
        border-color: var(--primary);
        background-color: var(--primary);
        color: var(--light);
        .menu .dropdown > .btn {
          color: var(--light);
        }
        .pf-form-boolean-values {
          border-color: var(--light);
        }
      }
    }

    .pf-form-boolean-value {
      display: flex;
      flex-wrap: nowrap;
    }

    /* drag handle */
    .handle {
      align-self: center;
      cursor: grab;
      flex-shrink: 0;
      margin: 0 .25rem;
      &:hover {
        color: var(--primary);
      }
    }

    /* add/del menu */
    .menu {
      align-self: center;
      cursor: pointer;
      flex-shrink: 0;
      .dropdown > .btn { // menu dropdown
        /*
        margin-right: .5rem;
        */
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
  }
</style>
