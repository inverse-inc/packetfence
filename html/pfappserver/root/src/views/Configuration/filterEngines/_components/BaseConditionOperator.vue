<template>
  <div :draggable="draggable" v-on="bindListeners"
   class="base-condition mb-3" align-v="center">

    <div class="base-condition-operator">
      <span v-if="draggable"
        class="drag-handle m-1" :class="{ 'text-secondary': disabled }">
        <icon name="th"/>
      </span>
      <base-input-chosen-one
        :namespace="`${namespace}.op`"
        :options="operatorOptions"
        :disabled="disabled"
        class="m-1"
      />
      <b-dropdown ref="menu"
        :disabled="disabled"
        class="m-1" variant="transparent"
        no-caret lazy right
      >
        <template v-slot:button-content>
          <icon name="cog"/>
        </template>
        <b-dropdown-group>
          <b-dropdown-item @click="onAddOperator">
            <icon name="grip-horizontal" class="mr-1"/> {{ $t('Add Operator') }}
          </b-dropdown-item>
          <b-dropdown-item @click="onAddValue">
            <icon name="ellipsis-h" class="mr-1"/> {{ $t('Add Value') }}
          </b-dropdown-item>
        </b-dropdown-group>
        <b-dropdown-group v-if="draggable">
          <b-dropdown-item @click="onClone">
            <icon name="clone" class="mr-1"/> {{ $t('Clone') }}
          </b-dropdown-item>
          <b-dropdown-item @click="onDelete">
            <icon name="trash-alt" class="mr-1"/> {{ $t('Delete') }}
          </b-dropdown-item>
        </b-dropdown-group>
        <b-dropdown-group v-else>
          <b-dropdown-item @click="onTruncate">
            <icon name="cut" class="mr-1"/> {{ $t('Truncate') }}
          </b-dropdown-item>
        </b-dropdown-group>
      </b-dropdown>
    </div>

    <div v-if="operatorValues" class="base-condition-values">
      <template v-for="(value, index) in operatorValues">

        <!-- placeholder (before: n)-->
        <component v-if="dragTargetIndex === index"
          :is="placeholderComponent"
          :key="`placeholder-op-${index}`"
          class="drag-placeholder w-100"
        />

        <!-- recursive (self) -->
        <base-condition-operator v-if="'values' in value"
          :namespace="`${namespace}.values.${index}`"
          :key="`op-${index}`"
          :class="{
            'drag-source': dragSourceIndex === index,
          }"
          :disabled="disabled"
          draggable
          @clone="onChildCloneValue(index)"
          @delete="onChildDeleteValue(index)"
          @dragstart="onDragStart(index, $event)"
          @dragover="onDragOver(index, $event)"
          @dragleave="onDragLeave(index, $event)"
          @dragend="onDragEnd(index, $event)"
          @drop="onDrop($event)"
        />

        <base-condition-value v-else
          :namespace="`${namespace}.values.${index}`"
          :key="`value-${index}`"
          :class="{
            'drag-source': dragSourceIndex === index,
          }"
          :disabled="disabled"
          @clone="onChildCloneValue(index)"
          @delete="onChildDeleteValue(index)"
          @dragstart="onDragStart(index, $event)"
          @dragover="onDragOver(index, $event)"
          @dragend="onDragEnd(index, $event)"
          @drop="onDrop($event)"
        />

        <!-- placeholder (after: n + 1)-->
        <component v-if="dragTargetIndex === index + 1 && dragTargetIndex === operatorValues.length"
          :is="placeholderComponent"
          :key="`placeholder-op-${index + 1}`"
          class="drag-placeholder w-100"
        />

      </template>
    </div>

  </div>
</template>
<script>
import { computed, nextTick, toRefs } from '@vue/composition-api'
import useDraggable from '@/composables/useDraggable'
import { useInputMeta, useInputMetaProps, useNamespaceMetaAllowed } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import {
  BaseInput,
  BaseInputChosenOne
} from '@/components/new/'
import BaseConditionValue from './BaseConditionValue'
import { pfOperators } from '@/globals/pfOperators'

const components = {
  BaseConditionValue,
  BaseInput,
  BaseInputChosenOne
}

const props = {
  ...useInputMetaProps,
  ...useInputValueProps,

  disabled: {
    type: Boolean,
  },
  draggable: {
    type: Boolean,
    default: false
  }
}

const setup = (props, context) => {

  const { emit } = context

  const {
    draggable,
    namespace
  } = toRefs(props)

  const metaProps = useInputMeta(props, context)
  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const rootNamespace = computed(() => {
    // eslint-disable-next-line no-unused-vars
    const [ root, ...extras ] = (namespace.value || '').split('.')
    return root
  })

  const operatorOptions = computed(() => useNamespaceMetaAllowed(`${rootNamespace.value}.op`)
    .filter(({ requires = [] }) => requires.includes('values') || requires.length === 0)
    .map(({ value }) => {
        const { [value]: text = value } = pfOperators
        return { text, value }
    })
    //.sort((a, b) => a.text.localeCompare(b.text)) // use natural order
  )

  const operatorValues = computed(() => {
    const { values = [] } = value.value || {}
    return values
  })

  const onClone = () => new Promise((resolve) => {
    emit('clone')
    nextTick(resolve)
  })
  const onDelete = () => new Promise((resolve) => {
    emit('delete')
    nextTick(resolve)
  })

  const onAddOperator = () => {
    const newOperator = { op: undefined, values: [{ field: undefined, op: undefined, value: undefined }] }
    return onInput({ ...value.value, values: [ ...value.value.values, newOperator ] })
  }

  const onAddValue = () => {
    const newValue = { field: undefined, op: undefined, value: undefined }
    return onInput({ ...value.value, values: [ ...value.value.values, newValue ] })
  }

  const onTruncate = () => onInput({ ...value.value, values: [] })

  const onChildCloneValue = (index) => {
    const { values = [], values: { [index]: newValue } = {} } = value.value || {}
    const dereferencedValue = Object.assign({}, newValue) // dereference
    return onInput({ ...value.value, values: [...values.slice(0, index + 1), dereferencedValue, ...values.slice(index + 1)] })
  }

  const onChildDeleteValue = (index) => {
    const { values = [] } = value.value || {}
    if (values.length <= 1 && draggable.value) // don't allow empty `values` (except @root)
      return onDelete() // delete self
    else
      return onInput({ ...value.value, values: [...values.slice(0, index), ...values.slice(index + 1)] })
  }

  const getValueFn = (index) => {
    const { values: { [index]: _value } = {} } = value.value || {}
    return _value
  }

  const setValueFn = (index, newValue) => {
    if (newValue) {
      const { values = [] } = value.value || {}
      return onInput({ ...value.value, values: [...values.slice(0, index), newValue, ...values.slice(index)] })
    }
    else
      return onChildDeleteValue(index)
  }

  const {
    bindListeners,
    placeholderComponent,
    dragSourceIndex,
    dragTargetIndex,
    onDragStart,
    onDragOver,
    onDragLeave,
    onDragEnd,
    onDrop
  } = useDraggable(context, getValueFn, setValueFn)

  return {
    // useInputValue
    inputValue: value,

    // useDraggable
    bindListeners,
    placeholderComponent,
    dragSourceIndex,
    dragTargetIndex,
    onDragStart,
    onDragOver,
    onDragLeave,
    onDragEnd,
    onDrop,

    operatorOptions,
    operatorValues,
    onClone,
    onDelete,
    onAddOperator,
    onAddValue,
    onTruncate,
    onChildCloneValue,
    onChildDeleteValue,
  }
}

// @vue/component
export default {
  name: 'base-condition-operator',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.input-group > .base-condition {
  overflow: visible !important;
}
</style>
