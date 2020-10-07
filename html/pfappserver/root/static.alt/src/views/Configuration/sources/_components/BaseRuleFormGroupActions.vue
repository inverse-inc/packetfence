<template>
  <b-form-group ref="form-group"
    class="base-form-group base-rule-form-group-actions"
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
      >{{ $t('Add Action') }}</b-button>

      <draggable v-else ref="draggableRef"
        class="w-100 mx-3"
        handle=".draggable-handle"
        ghost-class="draggable-copy"
        v-on="draggableListeners"
      >
        <b-row v-for="(item, index) in inputValue" :key="draggableKeys[index]">
          <b-col class="col-form-label text-center py-2" :class="{
            'draggable-on': isSortable,
            'draggable-off': !isSortable
          }">
            <icon v-if="isSortable"
              class="draggable-handle" name="th" scale="1.5"
              v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"
            />
            <span class="draggable-index">{{ index + 1 }}</span>
          </b-col>
          <b-col cols="10" class="py-2">
            <base-rule-action ref="base-rule-action"
              :namespace="`${namespace}.${index}`"
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
      </draggable>
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
import { computed, nextTick, unref } from '@vue/composition-api'
import draggable from 'vuedraggable'
import BaseRuleAction from './BaseRuleAction'

const components = {
  draggable,
  BaseRuleAction
}

import useEventActionKey from '@/composables/useEventActionKey'
import { useArrayDraggable } from '@/composables/useArrayDraggable'
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
  ...useInputValueProps
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

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
    draggableRef,
    draggableKeys,

    add: draggableAdd,
    copy: draggableCopy,
    remove: draggableRemove,
    truncate: draggableTruncate,

    draggableListeners
  } = useArrayDraggable(value, onChange, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  const actionKey = useEventActionKey(/* document */)

  const isSortable = computed(() => {
    return !unref(isLocked) && unref(value).length > 1
  })

  const itemAdd = (index = 0) => {
    const _value = unref(value)
    const isCopy = unref(actionKey) && index - 1 in _value
    if (isCopy) {
      draggableCopy(index - 1, index).then(([fromComponent, toComponent]) => {
        const { isCollapse } = fromComponent
        if (!isCollapse) {
          const { onExpand = () => {} } = toComponent
          onExpand()
        }
      })
    }
    else {
      draggableAdd(index, {
        foo: 'bar'
      }).then(newComponent => {
        const { onExpand = () => {} } = newComponent
        onExpand()
      })
    }
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
    draggableRef,
    draggableKeys,
    draggableListeners,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    isSortable,
    actionKey,
    itemAdd,
    itemDelete
  }
}

// @vue/component
export default {
  name: 'base-rule-form-group-actions',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.draggable-copy {
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
  .base-input-range {
    background-color: $white !important;
    .handle {
      color: $white !important;
      background-color: $primary !important;
    }

  }

}
.base-form-group {
  .draggable-off > .draggable-handle,
  .draggable-on:not(:hover) > .draggable-handle,
  .draggable-on:hover > .draggable-index {
    display: none;
  }
}
.base-rule-form-group-actions {
  & > .form-row > [role="group"] > .input-group {
    border: 1px solid transparent;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);

    & > div > .row {
      &:nth-child(even) {
        background-color: $table-border-color;
      }
      &:nth-child(odd) {
        background-color: $white;
      }
    }
    &.has-invalid:not([data-num="0"]) {
      border-color: $form-feedback-invalid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
    }
    &.has-valid:not([data-num="0"]) {
      border-color: $form-feedback-valid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-valid-color, .25);
    }
  }
}
</style>
