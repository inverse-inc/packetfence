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

    <form-group-name namespace="name"
      :column-label="$i18n.t('Name')"
    />

    <form-group-parent-identifier namespace="parent_id"
      :column-label="$i18n.t('Parent device')"
    />

  </base-form>
</template>
<script>
import {
  BaseForm
} from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupName,
  FormGroupParentIdentifier,
} from './'

const components = {
  BaseForm,
  FormGroupIdentifier,
  FormGroupName,
  FormGroupParentIdentifier,
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
