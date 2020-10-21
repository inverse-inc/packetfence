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

    <form-group-api-login-identifier namespace="api_login_id"
      :column-label="$i18n.t('API login ID')"
    />

    <form-group-transaction-key namespace="transaction_key"
      :column-label="$i18n.t('Transaction key')"
    />

    <form-group-public-client-key namespace="public_client_key"
      :column-label="$i18n.t('Public Client Key')"
    />

    <form-group-domains namespace="domains"
      :column-label="$i18n.t('Authorized domains')"
      :text="$i18n.t('Comma-separated list of domains that will be resolve with the correct IP addresses.')"
    />

    <form-group-currency namespace="currency"
      :column-label="$i18n.t('Currency')"
    />

    <form-group-test-mode namespace="test_mode"
      :column-label="$i18n.t('Test mode')"
    />

    <form-group-send-email-confirmation namespace="send_email_confirmation"
      :column-label="$i18n.t('Send billing confirmation')"
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
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupApiLoginIdentifier,
  FormGroupCreateLocalAccount,
  FormGroupCurrency,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupPublicClientKey,
  FormGroupSendEmailConfirmation,
  FormGroupTestMode,
  FormGroupTransactionKey,
} from './'

const components = {
  BaseForm,

  FormGroupApiLoginIdentifier,
  FormGroupCreateLocalAccount,
  FormGroupCurrency,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupPublicClientKey,
  FormGroupSendEmailConfirmation,
  FormGroupTestMode,
  FormGroupTransactionKey,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-authorize-net',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
