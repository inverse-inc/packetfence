<template>
  <div draggable v-on="$listeners"
    class="base-condition-value" align-v="center">

    <span class="drag-handle m-1" :class="{ 'text-secondary': isLoading }">
      <icon name="th"/>
    </span>

    <base-input-chosen-one v-if="operatorRequiresField"
      class="flex-grow-1 m-1"
      v-model="inputValueField"
      :options="fieldOptions"
    />

    <base-input-chosen-one
      v-model="inputValueOperator"
      class="flex-grow-1 m-1"
      :options="operatorOptions"
    />

    <template v-if="operatorRequiresValue">

      <base-input-chosen-one v-if="hasValueOptions"
        class="flex-grow-1 m-1"
        v-model="inputValueValue"
        :options="valueOptions"
      />

      <base-input v-else
        class="flex-grow-1 m-1"
        v-model="inputValueValue"
      />

    </template>

    <b-dropdown ref="menu"
      :disabled="isLoading"
      class="m-1" variant="transparent"
      no-caret lazy right
    >
      <template v-slot:button-content>
        <icon name="cog"/>
      </template>
      <b-dropdown-group>
        <b-dropdown-item @click="onClone">
          <icon name="clone" class="mr-1"/> {{ $t('Clone') }}
        </b-dropdown-item>
        <b-dropdown-item @click="onDelete">
          <icon name="trash-alt" class="mr-1"/> {{ $t('Delete') }}
        </b-dropdown-item>
      </b-dropdown-group>
    </b-dropdown>

  </div>
</template>
<script>
import {
  BaseInput,
  BaseInputChosenOne
} from '@/components/new/'
import BaseConditionOperator from './BaseConditionOperator'

const components = {
  BaseConditionOperator,
  BaseInput,
  BaseInputChosenOne
}

import { computed, customRef, ref } from '@vue/composition-api'
import { useInputMeta, useInputMetaProps, useNamespaceMetaAllowed } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import { pfOperators } from '@/globals/pfOperators'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const { emit } = context

  const metaProps = useInputMeta(props, context)
  const {
    value,
    onChange,
    onInput
  } = useInputValue(metaProps, context)

  const inputValueField = customRef((track, trigger) => ({
    get() {
      track()
      const { field } = value.value || {}
      return field
    },
    set(field) {
      onInput({ ...value.value, field })
      trigger()
    }
  }))

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

  const inputValueValue = customRef((track, trigger) => ({
    get() {
      track()
      const { value: _value } = value.value || {}
      return _value
    },
    set(_value) {
      onInput({ ...value.value, value: _value })
      trigger()
    }
  }))

  const isLoading = ref(false)

  const fieldOptions = computed(() => useNamespaceMetaAllowed('condition.field')
    .sort((a, b) => a.text.localeCompare(b.text))
  )

  const field = computed(() => {
    const { field } = value.value || {}
    return fieldOptions.value.find(fieldOption => {
      const { value } = fieldOption
      return value === field
    })
  })

  const operatorMeta = computed(() => useNamespaceMetaAllowed('condition.op'))
  const operatorOptions = computed(() => operatorMeta.value
    .filter(({ requires = [] }) => !requires.includes('values'))
    .map(({ value, requires }) => {
        const { [value]: text = value } = pfOperators
        return { text, value, requires }
    })
    //.sort((a, b) => a.text.localeCompare(b.text)) // use natural order
  )
  const operatorRequires = computed(() => {
    const { op } = value.value
    const { requires = [] } = operatorMeta.value.find(({ value }) => value === op) || {}
    return requires
  })
  const operatorRequiresField = computed(() => operatorRequires.value.length === 0 || operatorRequires.value.includes('field'))
  const operatorRequiresValue = computed(() => operatorRequires.value.length === 0 || operatorRequires.value.includes('value'))

  const valueOptions = computed(() => {
    if (field.value) {
      const { siblings: { value: { allowed_values = [] } = {} } = {} } = field.value
      return allowed_values
    }
    return []
  })
  const hasValueOptions = computed(() => valueOptions.value.length > 0)

  const onClone = () => emit('clone')
  const onDelete = () => emit('delete')

  return {
    // useInputValue
    onChange,
    onInput,
    inputValueField,
    inputValueOperator,
    inputValueValue,

    isLoading,
    fieldOptions,
    operatorOptions,
    operatorRequiresField,
    operatorRequiresValue,
    valueOptions,
    hasValueOptions,

    onClone,
    onDelete
  }
}

// @vue/component
export default {
  name: 'base-condition-value',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
