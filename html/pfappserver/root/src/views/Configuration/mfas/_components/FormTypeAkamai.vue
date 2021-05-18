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

    <form-group-app-id namespace="app_id"
      :column-label="$i18n.t('The App ID of the Akamai MFA')"
      :text="$i18n.t('Define the App ID provided by Akamai MFA.')"
    />

    <form-group-app-secret namespace="app_secret"
      :column-label="$i18n.t('The application secret of the Akamai MFA')"
      :text="$i18n.t('Define the application secret provided by Akamai MFA.')"
    />

  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupAppId,
  FormGroupAppSecret,
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupAppId,
  FormGroupAppSecret,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-akamai',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
