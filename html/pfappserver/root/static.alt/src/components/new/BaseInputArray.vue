<template>
  <div style="flex-grow: 100;">
    <b-button v-if="!inputLength" @click="itemAdd()"
      :variant="(inputState === false) ? 'outline-danger' : 'outline-secondary'"
      :disabled="isLocked"
    >{{ buttonLabel || $t('Add') }}</b-button>

    <div v-else
      class="base-input-array-items mx-3"
    >
      <b-row v-for="(item, index) in inputValue" :key="draggableKeys[index]"
        class="base-input-array-item align-items-center"
        :class="{
          'is-firstchild': index === 0,
          'is-lastchild': index === inputValue.length - 1
        }"
      >
        <b-col class="text-center">
          <span class="col-form-label ">{{ index + 1 }}</span>
        </b-col>
        <b-col cols="10">

          <component :is="childComponent" :ref="draggableKeys[index]"
            :namespace="`${namespace}.${index}`"
            v-bind="$props"
          />

        </b-col>
        <b-col>
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
    <small v-if="inputText"
      v-html="inputText"
    />
    <small v-if="inputInvalidFeedback"
      class="invalid-feedback"
      v-html="inputInvalidFeedback"
    />
    <small v-if="inputValidFeedback"
      class="valid-feedback"
      v-html="inputValidFeedback"
    />
  </div>
</template>
<script>
import { toRefs, unref } from '@vue/composition-api'

import useEventActionKey from '@/composables/useEventActionKey'
import { useArrayDraggable, useArrayDraggableProps } from '@/composables/useArrayDraggable'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

export const props = {
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
    draggableKeys,

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

    // useArrayDraggable
    draggableKeys,

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
  name: 'base-input-array',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.base-input-array-items {
  flex-grow: 100;
  & > .base-input-array-item {
    &:not(.is-lastchild) {
      border-bottom: $input-border-width solid $input-focus-bg;
    }
  }
}
</style>
