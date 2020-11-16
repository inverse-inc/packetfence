<template>
  <base-form-group-textarea v-bind="$props">
    <template v-slot:append>
      <div :title="tooltip" v-b-tooltip.hover.left.d300
        class="border-left border-secondary"
      >
        <base-button-upload @input="onInput"
          :accept="accept"
          :disabled="disabled"
          :isLoading="isLoading"
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

export const props = {
  ...BaseButtonUploadProps,
  ...BaseFormGroupTextareaProps,

  tooltip: {
    type: String,
    default: i18n.t('Click or drag-and-drop to upload a file')
  }
}

import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    onInput
  } = useInputValue(metaProps, context)

  return {
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
