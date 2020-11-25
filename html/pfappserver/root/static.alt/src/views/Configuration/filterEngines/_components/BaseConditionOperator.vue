<template>
  <div :draggable="draggable" v-on="$listeners"
   class="base-condition" align-v="center">

    <div class="base-condition-operator">
      <span v-if="draggable"
        class="drag-handle m-1" :class="{ 'text-secondary': isLoading }">
        <icon name="th"/>
      </span>
      <base-input-chosen-one
        v-model="inputValueOperator"
        :options="operatorOptions"
        class="m-1"
      />
      <b-dropdown ref="menu"
        :disabled="isLoading"
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

        <!-- placeholder (before)-->
        <template v-if="index === dragTargetIndex">
          <!-- recursive (self) -->
          <base-condition-operator v-if="'values' in bus"
            :key="`placeholder-op-${index}`"
            :value="bus"
            class="drag-placeholder"
            @dragover="onDragOver(index, $event)"
            @dragleave="onDragLeave(index, $event)"
            @dragend="onDragEnd(index, $event)"
            @drop="onDrop(index, $event)"
          />

          <base-condition-value v-else
            :key="`placeholder-value-${index}`"
            :value="bus"
            class="drag-placeholder"
            @dragover="onDragOver(index, $event)"
            @dragleave="onDragLeave(index, $event)"
            @dragend="onDragEnd(index, $event)"
            @drop="onDrop(index, $event)"
          />
        </template>

        <!-- recursive (self) -->
        <base-condition-operator v-if="'values' in value"
          :key="`op-${index}`"
          v-model="inputValueValues[index]"
          :class="{
            'drag-source': dragSourceIndex === index,
          }"
          @clone="onChildCloneValue(index)"
          @delete="onChildDeleteValue(index)"
          @dragstart="onDragStart(index, $event)"
          @dragover="onDragOver(index, $event)"
          @dragleave="onDragLeave(index, $event)"
          @dragend="onDragEnd(index, $event)"
          @drop="onDrop(index, $event)"
          draggable
        />

        <base-condition-value v-else
          :key="`value-${index}`"
          v-model="inputValueValues[index]"
          :class="{
            'drag-source': dragSourceIndex === index,
          }"
          @clone="onChildCloneValue(index)"
          @delete="onChildDeleteValue(index)"
          @dragstart="onDragStart(index, $event)"
          @dragover="onDragOver(index, $event)"
          @dragleave="onDragLeave(index, $event)"
          @dragend="onDragEnd(index, $event)"
          @drop="onDrop(index, $event)"
        />

      </template>
    </div>

  </div>
</template>
<script>
import { computed, customRef, ref, toRefs } from '@vue/composition-api'
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

  draggable: {
    type: Boolean,
    default: false
  }
}

const setup = (props, context) => {

  const { emit } = context

  const {
    draggable
  } = toRefs(props)

  const metaProps = useInputMeta(props, context)
  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const inputValueOperator = customRef((track, trigger) => ({
    get() {
      track()
      const { op } = value.value || {}
      return op
    },
    set(op) {
      onInput({ ...value.value, op })
      trigger()
    }
  }))

  const inputValueValues = customRef((track, trigger) => ({
    get() {
      track()
      const { values = [] } = value.value || {}
      return values
    },
    set(values) {
      onInput({ ...value.value, values })
      trigger()
    }
  }))

  const operatorOptions = computed(() => useNamespaceMetaAllowed('condition.op')
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

  const isLoading = ref(false)

  const onClone = () => emit('clone')
  const onDelete = () => emit('delete')

  const onAddOperator = () => {
    const newOperator = { op: undefined, values: [{ field: undefined, op: undefined, value: undefined }] }
    onInput({ ...value.value, values: [ ...value.value.values, newOperator ] })
  }

  const onAddValue = () => {
    const newValue = { field: undefined, op: undefined, value: undefined }
    onInput({ ...value.value, values: [ ...value.value.values, newValue ] })
  }

  const onTruncate = () => onInput({ ...value.value, values: [] })

  const onChildCloneValue = (index) => {
    const { values = [], values: { [index]: newValue } = {} } = value.value
    const dereferencedValue = Object.assign({}, newValue) // dereference
    onInput({ ...value.value, values: [...values.slice(0, index + 1), dereferencedValue, ...values.slice(index + 1)] })
  }

  const onChildDeleteValue = (index) => {
    const { values = [] } = value.value
    if (values.length <= 1 && draggable.value) // don't allow empty `values` (except @root)
      onDelete() // delete self
    else
      onInput({ ...value.value, values: [...values.slice(0, index), ...values.slice(index + 1)] })
  }

  const {
  bus,
    dragSourceIndex,
    dragTargetIndex,
    onDragStart,
    onDragOver,
    onDragLeave,
    onDragEnd,
    onDrop
  } = useDraggable(props)

  return {
    // useInputValue
    inputValueOperator,
    inputValueValues,

    isLoading,
    operatorOptions,
    operatorValues,

    onClone,
    onDelete,
    onAddOperator,
    onAddValue,
    onTruncate,

    onChildCloneValue,
    onChildDeleteValue,

    // useDraggable
bus,
    dragSourceIndex,
    dragTargetIndex,
    onDragStart,
    onDragLeave,
    onDragOver,
    onDragEnd,
    onDrop,
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
