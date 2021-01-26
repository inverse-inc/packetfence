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

    <form-group-email-required namespace="email_required"
      :column-label="$i18n.t('Email required')"
    />

    <form-group-authentication-rules namespace="authentication_rules"
      :column-label="$i18n.t('Authentication Rules')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupEmailRequired,
  FormGroupIdentifier,
} from './'

const components = {
  BaseForm,

  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupEmailRequired,
  FormGroupIdentifier,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-null',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
