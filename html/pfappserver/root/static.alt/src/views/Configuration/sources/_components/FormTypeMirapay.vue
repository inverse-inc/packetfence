<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General settings')" active>

        <form-group-identifier namespace="id"
          :column-label="$i18n.t('Name')"
          :disabled="!isNew && !isClone"
        />

        <form-group-description namespace="description"
          :column-label="$i18n.t('Description')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Iframe settings')">

        <form-group-base-url namespace="base_url"
          :column-label="$i18n.t('Iframe Base URL')"
        />

        <form-group-merchant-identifier namespace="merchant_id"
          :column-label="$i18n.t('Merchant ID')"
        />

        <form-group-shared-secret namespace="shared_secret"
          :column-label="$i18n.t('Shared Secret')"
          :text="$i18n.t('MKEY for the iframe.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Direct settings')">

        <form-group-direct-base-url namespace="direct_base_url"
          :column-label="$i18n.t('Direct Base url')"
        />

        <form-group-terminal-identifier namespace="terminal_id"
          :column-label="$i18n.t('Terminal ID')"
          :text="$i18n.t('Terminal ID for Mirapay Direct.')"
        />

        <form-group-shared-secret-direct namespace="shared_secret_direct"
          :column-label="$i18n.t('Shared Secret Direct')"
          :text="$i18n.t('MKEY for Mirapay Direct.')"
        />

        <form-group-terminal-group-identifier namespace="terminal_group_id"
          :column-label="$i18n.t('Terminal Group ID')"
          :text="$i18n.t('Terminal Group ID for Mirapay Direct.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Additional settings')">

        <form-group-service-fqdn namespace="service_fqdn"
          :column-label="$i18n.t('Service FQDN')"
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

      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import {
  FormGroupBaseUrl,
  FormGroupCreateLocalAccount,
  FormGroupCurrency,
  FormGroupDescription,
  FormGroupDirectBaseUrl,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupMerchantIdentifier,
  FormGroupPasswordLength,
  FormGroupSendEmailConfirmation,
  FormGroupServiceFqdn,
  FormGroupSharedSecret,
  FormGroupSharedSecretDirect,
  FormGroupTerminalGroupIdentifier,
  FormGroupTerminalIdentifier,
  FormGroupTestMode,
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupBaseUrl,
  FormGroupCreateLocalAccount,
  FormGroupCurrency,
  FormGroupDescription,
  FormGroupDirectBaseUrl,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupMerchantIdentifier,
  FormGroupPasswordLength,
  FormGroupSendEmailConfirmation,
  FormGroupServiceFqdn,
  FormGroupSharedSecret,
  FormGroupSharedSecretDirect,
  FormGroupTerminalGroupIdentifier,
  FormGroupTerminalIdentifier,
  FormGroupTestMode,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-mirapay',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
