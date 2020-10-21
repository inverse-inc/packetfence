<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Name')"
      :disabled="!isNew && !isClone"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
    />

    <form-group-api-key namespace="api_key"
      :column-label="$i18n.t('Kickbox.io API key')"
    />

    <form-group-authentication-rules namespace="authentication_rules"
      :column-label="$i18n.t('Authentication Rules')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupApiKey,
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupIdentifier,
} from './'

const components = {
  BaseForm,

  FormGroupApiKey,
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupIdentifier,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-kickbox',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
