<template>
  <component :is="component" v-bind="$props" v-on="$listeners" :tabIndex="(isUpload) ? -1 : undefined">
    <template v-slot:prepend>
      <b-dropdown v-if="isUpload" toggle-class="btn-transparent">
        <template #button-content>
          <icon name="file" class="mr-2" /> {{ fileDecorated.name }}
        </template>
        <b-dropdown-form style="width: 400px;">
          <b-media md="auto">
            <template v-slot:aside><icon name="file" scale="1.5" class="mt-2 mx-2"></icon></template>
            <strong>{{ fileDecorated.name }}</strong>
            <p class="small mt-3 mb-0">{{ fileDecorated.size }}</p>
            <p class="small mb-0">{{ fileDecorated.lastModifiedDate }}</p>
          </b-media>
        </b-dropdown-form>
        <b-dropdown-divider />
        <b-dropdown-form>
          <base-button-upload
            @input="onInput"
            @files="onFiles"
            :accept="uploadAccept"
            :encode="encode"
            class="btn btn-primary text-nowrap mr-2"
            size="sm"
            read-as-text
          >
            {{ $i18n.t('Replace') }}
          </base-button-upload>
          <b-button class="mr-2" size="sm" variant="danger" @click="onReset">{{ $i18n.t('Delete') }}</b-button>
        </b-dropdown-form>
      </b-dropdown>
      <base-button-upload v-else
        @input="onInput"
        @files="onFiles"
        :accept="accept"
        :encode="encode"
        :title="title"
        class="btn text-nowrap"
        read-as-text
      >
        <icon name="upload" class="my-2" />
      </base-button-upload>
    </template>
  </component>
</template>
<script>
import BaseFormGroupInput, { props as BaseFormGroupInputProps } from './BaseFormGroupInput'
import BaseButtonUpload, { props as BaseButtonUploadProps } from './BaseButtonUpload'
const components = {
  BaseButtonUpload
}

import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInputProps } from '@/composables/useInput'
import { useInputMetaProps } from '@/composables/useMeta'
import { useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValueProps } from '@/composables/useInputValue'
import { utf8ToBase64 } from '@/utils/strings'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupInputProps,
  ...BaseButtonUploadProps,

  // overload encode(ing)
  encode: {
    type: Function,
    default: utf8ToBase64
  },

  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,

  component: {
    type: Object,
    default: () => BaseFormGroupInput
  },
  title: {
    type: String,
    default: i18n.t('Upload File')
  }
}

import { computed, customRef, inject, ref, toRefs, watch } from '@vue/composition-api'
import { getFormNamespace, setFormNamespace } from '@/composables/useInputValue'
import { getMetaNamespace } from '@/composables/useMeta'
import bytes from '@/utils/bytes'

const setup = (props) => {

  const {
    accept,
    namespace,
  } = toRefs(props)

  const form = inject('form', ref({}))
  const meta = inject('meta', ref({}))

  const inputValue = customRef((track, trigger) => ({
    get() {
      track()
      return getFormNamespace(namespace.value.split('.'), form.value)
    },
    set(newValue) {
      setFormNamespace(namespace.value.split('.'), form.value, newValue)
      trigger()
    }
  }))

  const uploadNamespace = computed(() => `${namespace.value}_upload`.split('.'))

  const uploadValue = customRef((track, trigger) => ({
    get() {
      track()
      return getFormNamespace(uploadNamespace.value, form.value)
    },
    set(newValue) {
      setFormNamespace(uploadNamespace.value, form.value, newValue)
      trigger()
    }
  }))

  const uploadMeta = computed(() => getMetaNamespace(uploadNamespace.value, meta.value))
  const uploadAccept = computed(() => {
    const { accept: { ['default']: defaultMeta = accept.value } = {} } = uploadMeta.value
    return defaultMeta
  })

  const isUpload = ref(false)
  const file = ref(false)

  const onInput = value => {
    uploadValue.value = value
    inputValue.value = null
    isUpload.value = true
  }

  const onFiles = files => {
    if (files.length > 0)
      file.value = files[files.length - 1]
    else
      file.value = false
  }

  const fileDecorated = computed(() => {
    const { size } = file.value
    return {
      ...file.value,
      size: bytes.toHuman(size, 2, true) + 'B'
    }
  })

  const onReset = () => {
    uploadValue.value = null
    isUpload.value = false
    file.value = false
  }

  watch(inputValue, () => {
    if (isUpload.value && inputValue.value !== null) {
      onReset()
    }
  })

  return {
    isUpload,
    onInput,
    onFiles,
    onReset,
    fileDecorated,
    uploadAccept,
  }
}

// @vue/component
export default {
  name: 'base-form-group-file-upload',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">

</style>