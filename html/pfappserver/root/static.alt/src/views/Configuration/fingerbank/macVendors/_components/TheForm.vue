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
      :column-label="$i18n.t('MAC Vendor')"
    />

    <form-group-mac namespace="mac"
      :column-label="$i18n.t('OUI')"
      :text="$i18n.t('The OUI is the first six digits or letters of a MAC address. They must be entered without any space or separator (ex: 001122).')"
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
  FormGroupMac,
} from './'

const components = {
  BaseForm,
  FormGroupIdentifier,
  FormGroupName,
  FormGroupMac,
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

