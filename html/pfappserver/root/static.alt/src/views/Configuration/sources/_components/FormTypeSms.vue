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

    <form-group-sms-carriers namespace="sms_carriers"
      :column-label="$i18n.t('SMS Carriers')"
      :text="$i18n.t('List of phone carriers available to the user.')"
    />

    <form-group-sms-activation-timeout :namespaces="['sms_activation_timeout.interval', 'sms_activation_timeout.unit']"
      :column-label="$i18n.t('SMS Activation Timeout')"
      :text="$i18n.t('This is the delay given to a guest who registered by SMS confirmation to fill the PIN code.')"
    />

    <form-group-message namespace="message"
      :column-label="$i18n.t('SMS text message ($pin will be replaced by the PIN number)')"
    />

    <form-group-pin-code-length namespace="pin_code_length"
      :column-label="$i18n.t('PIN length')"
      :text="$i18n.t('The amount of digits of the PIN number.')"
    />

    <form-group-create-local-account namespace="create_local_account"
      :column-label="$i18n.t('Create Local Account')"
      :text="$i18n.t('Create a local account on the PacketFence system based on the username provided.')"
    />

    <form-group-hash-passwords namespace="hash_passwords"
      :column-label="$i18n.t('Database passwords hashing method')"
      :text="$i18n.t('The algorithm used to hash the passwords in the database.This will only affect newly created or reset passwords.')"
    />

    <form-group-password-length namespace="password_length"
      :column-label="$i18n.t('Password length')"
      :text="$i18n.t('The length of the password to generate.')"
    />

    <form-group-local-account-logins namespace="local_account_logins"
      :column-label="$i18n.t('Amount of logins for the local account')"
      :text="$i18n.t('The amount of times, the local account can be used after its created. 0 means infinite.')"
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
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupMessage,
  FormGroupPasswordLength,
  FormGroupPinCodeLength,
  FormGroupSmsActivationTimeout,
  FormGroupSmsCarriers,
} from './'

const components = {
  BaseForm,

  FormGroupAuthenticationRules,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupMessage,
  FormGroupPasswordLength,
  FormGroupPinCodeLength,
  FormGroupSmsActivationTimeout,
  FormGroupSmsCarriers,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-sms',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
