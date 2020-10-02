<template>
  <b-form-group ref="form-group"
    class="base-form-group base-form-group-rules"
    :class="{
      'mb-0': !columnLabel
    }"
    :state="inputState"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <b-input-group
      :class="{
        'is-valid': inputState === true,
        'is-invalid': inputState === false
      }"
    >
      <b-button v-if="!inputValue.length" @click="itemAdd()"
        :variant="(inputState === false) ? 'outline-danger' : 'outline-secondary'"
        :disabled="isLocked"
      >{{ $t('Add Rule') }}</b-button>

      <draggable v-else ref="draggable"
        class="w-100"
        handle=".draggable-handle"
        ghost-class="draggable-copy"
        v-model="inputValue"

        @start="onDragStart"
        @end="onDragEnd"
      >
        <b-row v-for="(item, index) in inputValue" :key="index">
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
            <base-rule ref="base-rule"
              :key="index"
              :namespace="`${namespace}.${index}`"
            />
          </b-col>
          <b-col class="py-2">
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
import { computed, nextTick, unref, watch } from '@vue/composition-api'
import draggable from 'vuedraggable'

import BaseRule from './BaseRule'
import useEventActionKey from '@/composables/useEventActionKey'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useInputMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

const components = {
  draggable,
  BaseRule
}

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
    onInput,
    onChange
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  const actionKey = useEventActionKey(/* document */)

  const isSortable = computed(() => {
    return !unref(isLocked) && unref(value).length > 1
  })

  const itemAdd = (index) => {
    const _value = unref(value)
    const isCopy = unref(actionKey)
    const newRow = (isCopy)
      ? JSON.parse(JSON.stringify(_value[index - 1])) // dereferenced copy
      : {/* noop, use default */}
    onChange([..._value.slice(0, index), newRow, ..._value.slice(index)])
  }

  const itemDelete = (index) => {
    const _value = unref(value)
    const isAll = unref(actionKey)
    if (isAll)
      onChange([])
    else
      onChange([..._value.slice(0, index), ..._value.slice(index + 1, _value.length)])
  }

  /**
    * vue-draggable cross-contaminates child components after dragend, where each
    *   child component maintains its DOM order and private state after being
    *   re-indexed, but receives new props from their namespace, thus cross-contaminating
    *   the component with the private state from the previous component at a given index.
    *
    * Any non-prop state (eg: isCollapsed) must be reset manually after an index change.
    */
  let isCollapseArray = []
  const onDragStart = () => { // store draggable::children::isCollapse
    const { refs: { draggable: { $children = [] } = {} } = {} } = context
    isCollapseArray = $children
      .filter(child => ('isCollapse' in child))
      .map(child => child.isCollapse)
  }

  const onDragEnd = ({newIndex, oldIndex}) => { // restore draggable::children::isCollapse
    if (newIndex >= isCollapseArray.length) {
      var k = newIndex - isCollapseArray.length + 1
      while (k--) {
        isCollapseArray.push(undefined)
      }
    }
    isCollapseArray.splice(newIndex, 0, isCollapseArray.splice(oldIndex, 1)[0])
    const { refs: { draggable: { $children } = {} } = {} } = context
    $children
      .filter(child => ('isCollapse' in child))
      .map(({isCollapse, onCollapse, onExpand}, index) => {
        if(isCollapse !== isCollapseArray[index])
          ((isCollapse) ? onExpand : onCollapse)()
      })
  }

  return {
    // useInput
    inputText: text,
    isLocked,

    // useInputValue
    inputValue: value,
    onInput,
    onChange,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    isSortable,
    actionKey,
    itemAdd,
    itemDelete,
    onDragStart,
    onDragEnd
  }
}

// @vue/component
export default {
  name: 'base-form-group-rules',
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
.base-form-group-rules {
  .input-group > div > .row {
    &:nth-child(even) {
      background-color: $table-border-color;
    }
  }
}
</style>
