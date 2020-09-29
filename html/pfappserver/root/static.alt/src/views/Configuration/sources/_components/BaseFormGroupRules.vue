<template>
  <b-form-group ref="form-group"
    class="base-form-group"
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
      <base-draggable
        :namespace="namespace"
      >
        <b-row v-for="(item, index) in inputValue" :key="index"
          align-v="top"
        >
          <b-col class="col-form-label text-center" :class="{
            'draggable-on': isSortable,
            'draggable-off': !isSortable
          }">
            <icon v-if="isSortable"
              class="draggable-handle" name="th" scale="1.5" v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"></icon>
            <span class="draggable-index">{{ index + 1 }}</span>
          </b-col>
          <b-col cols="10">
            <base-rule
              :key="index"
              :namespace="`${namespace}.${index}`"
            />
          </b-col>
          <b-col>
            Post
          </b-col>
        </b-row>
      </base-draggable>
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
import { unref, computed } from '@vue/composition-api'

import {
  BaseDraggable
} from '@/components/new/'
import BaseRule from './BaseRule'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useInputMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

const components = {
  BaseDraggable,
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

  const isSortable = computed(() => {
    return !unref(isLocked) && unref(value).length > 1
  })

  return {
    // useInput
    inputText: text,

    // useInputValue
    inputValue: value,
    onInput,
    onChange,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    isSortable
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
/*
  @include border-radius($border-radius);
  @include transition($custom-forms-transition);
  outline: 0;
*/
  padding-top: .25rem !important;
  padding-bottom: .0625rem !important;
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
</style>
