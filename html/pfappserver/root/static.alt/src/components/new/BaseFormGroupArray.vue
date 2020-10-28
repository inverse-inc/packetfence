<template>
  <b-form-group ref="form-group"
    class="base-form-group-array"
    :class="{
      'mb-0': !columnLabel
    }"
    :state="inputState"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <b-input-group
      :class="{
        'has-valid': inputState === true,
        'has-invalid': inputState === false
      }"
      :data-num="inputLength"
    >
      <b-button v-if="!inputLength" @click="itemAdd()"
        :variant="(inputState === false) ? 'outline-danger' : 'outline-secondary'"
        :disabled="isLocked"
      >{{ buttonLabel || $t('Add') }}</b-button>

      <div v-else
        class="w-100 mx-3"
      >
        <b-row v-for="(item, index) in inputValue" :key="index">
          <b-col class="text-center py-2">
            <span class="col-form-label ">{{ index + 1 }}</span>
          </b-col>
          <b-col cols="10" class="py-2">

            <component :is="component"
              :namespace="`${namespace}.${index}`"
              v-bind="$props"
            />

          </b-col>
          <b-col class="py-2 text-nowrap">
            <b-link @click="itemDelete(index)"
              :class="{
                'text-primary': actionKey,
                'text-secondary': !actionKey
              }"
              :disabled="isLocked"
              v-b-tooltip.hover.left.d300 :title="actionKey ? $t('Delete All') : $t('Delete Row')"
            >
              <icon name="minus-circle" class="cursor-pointer mx-1"/>
            </b-link>
            <b-link @click="itemAdd(index + 1)"
              :class="{
                'text-primary': actionKey,
                'text-secondary': !actionKey
              }"
              :disabled="isLocked"
              v-b-tooltip.hover.left.d300 :title="actionKey ? $t('Clone Row') : $t('Add Row')"
            >
              <icon name="plus-circle" class="cursor-pointer mx-1"/>
            </b-link>
          </b-col>
        </b-row>
      </div>
    </b-input-group>
    <template v-slot:description v-if="inputText">
      <div v-html="inputText"/>
    </template>
    <template v-slot:invalid-feedback v-if="inputInvalidFeedback">
      <div v-html="inputInvalidFeedback"/>
    </template>
    <template v-slot:valid-feedback v-if="inputValidFeedback">
      <div v-html="inputValidFeedback"/>
    </template>
  </b-form-group>
</template>
<script>
import { toRefs, unref } from '@vue/composition-api'

import useEventActionKey from '@/composables/useEventActionKey'
import { useArrayDraggable, useArrayDraggableProps } from '@/composables/useArrayDraggable'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

export const props = {
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,
  ...useArrayDraggableProps,

  buttonLabel: {
    type: String
  }
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    defaultItem
  } = toRefs(metaProps)

  const {
    text,
    isLocked
  } = useInput(metaProps, context)

  const {
    value,
    length,
    onInput,
    onChange
  } = useInputValue(metaProps, context)

  const {
    add: draggableAdd,
    copy: draggableCopy,
    remove: draggableRemove,
    truncate: draggableTruncate
  } = useArrayDraggable(props, context, value, onChange)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value, true) // recursive

  const actionKey = useEventActionKey(/* document */)

  const itemAdd = (index = 0) => {
    const _value = unref(value)
    const isCopy = unref(actionKey) && index - 1 in _value
    if (isCopy)
      draggableCopy(index - 1, index)
    else
      draggableAdd(index, unref(defaultItem))
  }

  const itemDelete = (index) => {
    const isAll = unref(actionKey)
    if (isAll)
      draggableTruncate()
    else
      draggableRemove(index)
  }

  return {
    // useInput
    inputText: text,
    isLocked,

    // useInputValue
    inputValue: value,
    inputLength: length,
    onInput,
    onChange,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    actionKey,
    itemAdd,
    itemDelete
  }
}

// @vue/component
export default {
  name: 'base-form-group-array',
  inheritAttrs: false,
  props,
  setup
}
</script>
