<template>
  <base-form-group
    class="form-group base-form-group-switch"
    :column-label="columnLabel"
    :content-cols="contentCols"
    :content-cols-sm="contentColsSm"
    :content-cols-md="contentColsMd"
    :content-cols-lg="contentColsLg"
    :content-cols-xl="contentColsXl"
    :label-class="labelClass"
    :label-cols="labelCols"
    :label-cols-sm="labelColsSm"
    :label-cols-md="labelColsMd"
    :label-cols-lg="labelColsLg"
    :label-cols-xl="labelColsXl"
    :text="text"
  >
    <base-input-switch :disabled="isLocked"
                       :size="size"
                       :onChange="onChange"
                       :value="switchValue"
    />
    <template v-slot:prepend v-if="$slots.prepend">
      <slot name="prepend"></slot>
    </template>
    <template v-slot:append v-if="$slots.append">
      <slot name="append"></slot>
    </template>
  </base-form-group>
</template>
<script>
import {useFormGroupProps} from '@/composables/useFormGroup'
import {useInput, useInputProps} from '@/composables/useInput'
import {useInputMeta, useInputMetaProps} from '@/composables/useMeta'
import {useInputValidator, useInputValidatorProps} from '@/composables/useInputValidator'
import {
  getFormNamespace,
  setFormNamespace,
  useInputValue,
  useInputValueProps
} from '@/composables/useInputValue'
import BaseFormGroup from './BaseFormGroup'
import BaseInputSwitch from './BaseInputSwitch.vue'
import {computed, inject, unref} from '@vue/composition-api';

const components = {
  BaseFormGroup,
  BaseInputSwitch
}

export const props = {
  onChange: {
    type: Function,
    default: () => {
    }
  },
  switchValue: {
    type: Boolean,
  },
  isLocked: {
    type: Boolean,
    default: false
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
  isFocus: {
    default: false,
    type: Boolean
  },
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,
}


// @vue/component
export default {
  name: 'on-change-form-group-switch',
  inheritAttrs: false,
  components,
  props
}
</script>
<style lang="scss">
.base-form-group-switch {
  .input-group {
    padding-bottom: 0px !important;
  }
}
</style>
