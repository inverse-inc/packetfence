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

    <form-group-radius-mfa-method namespace="radius_mfa_method"
      :column-label="$i18n.t('RADIUS OTP Method')"
      :text="$i18n.t('Define the method to be used in RADIUS to trigger OTP.')"
    />

    <form-group-split-char namespace="split_char"
      :column-label="$i18n.t('Character separator')"
      :text="$i18n.t('Please specify the char to split password field to get the code.')"
    />

    <form-group-cache-duration namespace="cache_duration"
      :column-label="$i18n.t('Cache duration')"
      :text="$i18n.t('The duration time that is use to cache the MFA information. This approximately represent the time for the user to complete the authentication.')"
    />

  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupRadiusMfaMethod,
  FormGroupSplitChar,
  FormGroupCacheDuration,
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupRadiusMfaMethod,
  FormGroupSplitChar,
  FormGroupCacheDuration
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-otp',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
