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

    <form-group-signing-key namespace="signing_key"
      :column-label="$i18n.t('The signing key of the Akamai MFA')"
      :text="$i18n.t('Define the signing key provided by Akamai MFA.')"
    />

    <form-group-verify-key namespace="verify_key"
      :column-label="$i18n.t('The verify key of the Akamai MFA')"
      :text="$i18n.t('Define the verify key provided by Akamai MFA.')"
    />

    <form-group-host namespace="host"
      :column-label="$i18n.t('The host of the Akamai MFA')"
      :text="$i18n.t('Define the host of the Akamai MFA.')"
    />

    <form-group-callback-url namespace="callback_url"
      :column-label="$i18n.t('The callback url to redirect back the user to PacketFence')"
      :text="$i18n.t('Define the callback URL to redirect the user to PacketFence.')"
    />

    <form-group-radius-mfa-method namespace="radius_mfa_method"
      :column-label="$i18n.t('RADIUS OTP Method')"
      :text="$i18n.t('Define the method to be used in RADIUS to trigger OTP.')"
    />

    <form-group-split-char namespace="split-char"
      :column-label="$i18n.t('Character separator')"
      :text="$i18n.t('Please specify the char to split password field to get the code.')"
    />

  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupAppId,
  FormGroupSigningKey,
  FormGroupVerifyKey,
  FormGroupHost,
  FormGroupCallbackUrl,
  FormGroupRadiusMfaMethod,
  FormGroupSplitChar,
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupAppId,
  FormGroupSigningKey,
  FormGroupVerifyKey,
  FormGroupHost,
  FormGroupCallbackUrl,
  FormGroupRadiusMfaMethod,
  FormGroupSplitChar,
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
