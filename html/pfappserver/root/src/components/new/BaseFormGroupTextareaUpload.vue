<template>
  <base-form-group-textarea v-bind="$props">
    <template v-slot:append>
      <div :title="tooltip" v-b-tooltip.hover.left.d300
        class="border-left border-secondary"
      >
        <base-button-upload v-if="!isLocked"
          @input="onInput"
          :accept="accept"
          class="btn btn-outline-light"
          read-as-text
        >
          <icon name="upload" class="text-secondary" />
        </base-button-upload>
      </div>
    </template>
  </base-form-group-textarea>
</template>
<script>
import i18n from '@/utils/locale'
import BaseButtonUpload, { props as BaseButtonUploadProps } from './BaseButtonUpload'
import BaseFormGroupTextarea, { props as BaseFormGroupTextareaProps } from './BaseFormGroupTextarea'

const components = {
  BaseButtonUpload,
  BaseFormGroupTextarea
}

import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'

export const props = {
  ...BaseButtonUploadProps,
  ...BaseFormGroupTextareaProps,
  ...useInputProps,

  tooltip: {
    type: String,
    default: i18n.t('Click or drag-and-drop to upload a file')
  }
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    isLocked
  } = useInput(metaProps, context)

  const {
    onInput
  } = useInputValue(metaProps, context)

  return {
    isLocked,
    onInput
  }
}

// @vue/component
export default {
  name: 'base-form-group-textarea-upload',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
