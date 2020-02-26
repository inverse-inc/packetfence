<template>
  <div class="pf-form-boolean" :class="{ 'root': isRoot, 'highlight': highlight }"
    :draggable="!isRoot"
    @dragstart.stop="$emit('dragStart', $event)"
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
        <span v-if="!isRoot" class="drag-handle">
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

    <div v-if="hasValues" class="pf-form-boolean-values"
      @mousemove="highlight = false"
    >
      <template v-for="(value, index) in valuesPlusOne">

        <!-- drag/drop placeholder -->
        <pf-form-boolean v-if="index === targetIndex" :key="'placeholder-' + index" :isRoot="false" class="drag-placeholder"
          v-model="eventBus.cache.value" :formStoreName="eventBus.cache.formStoreName" :formNamespace="eventBus.cache.formNamespace"
          @dragOver="dragOver(index, $event)"
          @dropValuePrev="dropValueNext(index - 1, $event)"
          @dropValueNext="dropValuePrev(index + 1, $event)"
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

        <!-- recurse -->
        <pf-form-boolean v-if="value" v-bind="attrs(index)" :key="index" :isRoot="false" :eventBus="eventBus" :class="{ 'drag-source': index === sourceIndex }"
          @addOperator="addOperator(index)"
          @cloneOperator="cloneOperator(index)"
          @deleteOperator="deleteOperator(index)"
          @addValue="addValue(index)"
          @cloneValue="cloneValue(index)"
          @deleteValue="deleteValue(index)"

          @dragStart="dragStart(index, $event)"
          @dragOver="dragOver(index, $event)"
          @dragEnd="dragEnd(index, $event)"
          @dropValuePrev="dropValuePrev(index)"
          @dropValueNext="dropValueNext(index)"
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
      <span class="drag-handle">
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
  const { width, height, top, left } = target.closest('.pf-form-boolean').getBoundingClientRect()
  /* 2 drop zones, CSS flex-box layout can be either vertical or horizontal
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
    eventBus: { // singleton event bus shared /w all recursive children
      type: Object,
      default: new Vue({
        data () {
          return {
            cache: false
          }
        }
      })
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
      const { inputValue: { op } = {} } = this
      return op || null
    },
    values () {
      const { inputValue: { values } = {} } = this
      return values || []
    },
    valuesPlusOne () {
      return [ ...this.values, null ] // +1 stub for extra placeholder @ end
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
      this.$set(this.inputValue, 'values', [...values.slice(0, index + 1), newValue, ...values.slice(index + 1)])
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
      this.$set(this.inputValue, 'values', [...values.slice(0, index + 1), newOp, ...values.slice(index + 1)])
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
      const { target: source, clientX: x, clientY: y } = event
      if (!document.elementFromPoint(x, y).closest('.drag-handle, .pf-form-boolean').classList.contains('drag-handle')) { // not a handle
        event.preventDefault() // cancel drag
        return
      }
      this.sourceIndex = index
      this.eventBus.$on('drag-end', () => {
        this.sourceIndex = false
        if (this.targetIndex === false) {
          this.eventBus.$off('drag-end')
        }
      })
      const { inputValue, formStoreName, formNamespace, actionKey: clone } = this
      let { values: { [index]: value } = {} } = inputValue
      try { // dereference
        value = JSON.parse(JSON.stringify(value))
      } catch (err) {
        value = (value && Object.keys(value).length > 0)
          ? Object.assign({}, value)
          : null
      }
      new Promise((resolve, reject) => {
        this.eventBus.cache = { source, clone, value, resolve, reject, formStoreName, formNamespace: `${formNamespace}.values.${index}` }
      }).then(({ index: dropIndex }) => { // drop success
        if (!clone) { // delete old value
          if (this.targetIndex !== false && dropIndex < index) { // drag/drop from/to same parent (above only)
            index++
          }
          this.$set(inputValue, 'values', [...inputValue.values.slice(0, index), ...inputValue.values.slice(index + 1)])
        }
        this.eventBus.$emit('drag-end')
      }).catch(() => { // drop cancelled
        // noop
      })
      this.$store.dispatch('events/onKeyUp') // fix: unable to detect actionKey change while dragging
    },
    dragEnd () { // @source
      this.eventBus.$emit('drag-end')
    },
    dragOver (index, event) { // @target
      event.preventDefault() // always allow drop
      let { target } = event
      target = target.closest('.pf-form-boolean')
      if (target.classList.contains('root')) return // ignore root children
      if (target.classList.contains('drag-placeholder')) return // ignore placeholder
      const { eventBus: { cache: { source, clone } = {} } = {} } = this
      if (source) {
        if (source.isSameNode(target)) return // ignore self
        if (source.contains(target)) return // ignore child nodes
        switch (isBefore(event)) {
          case true: // before @target
            if (!clone && target.previousElementSibling && target.previousElementSibling.isSameNode(source)) { // ignore self
              return
            }
            this.targetIndex = index
            break
          case false: // after @target
            if (!clone && target.nextElementSibling && target.nextElementSibling.isSameNode(source)) { // ignore self
              return
            }
            this.targetIndex = index + 1
            break
        }
        if (this.targetIndex !== false) {
          this.eventBus.$on('drag-over', ({ target }) => {
            const { 0: { childNodes = [] } = {} } = this.$el.getElementsByClassName('pf-form-boolean-values')
            if (Array.from(childNodes).indexOf(target) === -1) { // target is not an immediate child
              this.targetIndex = false
              this.eventBus.$off('drag-over')
            }
          })
          this.eventBus.$on('drag-end', () => {
            const { eventBus: { cache: { reject = () => {} } = {} } = {} } = this
            reject()
            this.targetIndex = false
            this.$set(this.eventBus, 'cache', false)
            if (this.sourceIndex !== false) {
              this.eventBus.$off('drag-end')
            }
          })
        }
        this.eventBus.$emit('drag-over', { target })
      }
    },
    dragDrop (event) { // @target
      if (isBefore(event)) { // previous
        this.$emit('dropValuePrev')
      } else { // next
        this.$emit('dropValueNext')
      }
    },
    dropValuePrev (index) {
      this.dropValue(index)
    },
    dropValueNext (index) {
      this.dropValue(index + 1)
    },
    dropValue (index) {
      const { inputValue: { values = [] } = {}, eventBus: { cache: { value, resolve = () => {} } = {} } = {} } = this
      this.$set(this.inputValue, 'values', [...values.slice(0, index), value, ...values.slice(index)])
      resolve({ index })
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
    border-radius: 0.5rem;
    transition: background-color .3s ease-out,
      border-color .3s ease-out;

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

    &.drag-placeholder {
      border-color: var(--primary);
      background-color: var(--primary);
      svg {
        visibility: hidden;
      }
      .pf-form-boolean-values {
        border-color: var(--light);
      }
    }

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
      &:drop-hover {
        outline: 1px solid var(--primary);
      }
    }

    .pf-form-boolean-value {
      display: flex;
      flex-wrap: nowrap;
    }

    &.drag-source {
      opacity: .5;
    }

    .drag-handle {
      align-self: center;
      cursor: grab;
      flex-shrink: 0;
      margin: 0 .25rem;
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
  }
</style>
