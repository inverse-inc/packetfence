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

    <form-group-auth-base-url namespace="auth_base_url"
      :column-label="$i18n.t('Auth base URL')"
      :text="$i18n.t('The base authentication URL for ZTCore')"
    />

    <form-group-assertion-url namespace="assertion_url"
      :column-label="$i18n.t('Assertion URL')"
      :text="$i18n.t('The URL where ZTCore should send its assertion. Change pf.example.com with the domain name of your captive-portal')"
    />

  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAuthBaseUrl,
  FormGroupAssertionUrl,
  FormGroupDescription,
  FormGroupIdentifier,
} from './'

const components = {
  BaseForm,

  FormGroupAuthBaseUrl,
  FormGroupAssertionUrl,
  FormGroupDescription,
  FormGroupIdentifier,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-ztcore',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
