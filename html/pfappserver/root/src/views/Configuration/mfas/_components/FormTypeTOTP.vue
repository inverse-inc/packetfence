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
      :text="$i18n.t('The char with which the password and the code are split during RADIUS authentication.')"
    />

    <form-group-cache-duration namespace="cache_duration"
      :column-label="$i18n.t('Cache duration')"
      :text="$i18n.t('The duration that is used to cache the MFA information. This should approximately represent the time for the user to complete the authentication.')"
    />

    <form-group-post-mfa-validation-cache-duration namespace="PostMfaValidationCacheDuration"
      :column-label="$i18n.t('Post MFA Validation Cache Duration')"
      :text="$i18n.t('The duration time to keep the information the user did validate the MFA authentication (represent the time between the portal validation and the next RADIUS request).')"
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
  FormGroupPostMfaValidationCacheDuration,
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupRadiusMfaMethod,
  FormGroupSplitChar,
  FormGroupCacheDuration,
  FormGroupPostMfaValidationCacheDuration
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-totp',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
