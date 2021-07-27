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
      :column-label="$i18n.t('The host of the Akamai Bind v2 MFA')"
      :text="$i18n.t('Define the host of the Akamai Bind v2 MFA.')"
    />

    <form-group-callback-url namespace="callback_url"
      :column-label="$i18n.t('The callback url to redirect back the user to PacketFence')"
      :text="$i18n.t('Define the callback URL to redirect the user to PacketFence.')"
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
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupAppId,
  FormGroupSigningKey,
  FormGroupVerifyKey,
  FormGroupHost,
  FormGroupCallbackUrl,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-akamai-bind-v2',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
