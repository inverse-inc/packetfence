<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
  >

    <form-group-identifier v-show="!isNew && !isClone"
      namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="true"
    />

    <form-group-value namespace="value"
      :column-label="$i18n.t('User Agent')"
    />

  </base-form>
</template>
<script>
import {
  BaseForm
} from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupValue,
} from './'

const components = {
  BaseForm,
  FormGroupIdentifier,
  FormGroupValue,
}

import { useForm, useFormProps as props } from '../_composables/useForm'

export const setup = (props, context) => useForm(props, context)

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

