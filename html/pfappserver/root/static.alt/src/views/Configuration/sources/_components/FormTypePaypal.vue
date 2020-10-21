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

    <form-group-currency namespace="currency"
      :column-label="$i18n.t('Currency')"
    />

    <form-group-test-mode namespace="test_mode"
      :column-label="$i18n.t('Test mode')"
    />

    <form-group-send-email-confirmation namespace="send_email_confirmation"
      :column-label="$i18n.t('Send billing confirmation')"
    />

    <form-group-identity-token namespace="identity_token"
      :column-label="$i18n.t('Identity token')"
    />

    <form-group-cert-identifier namespace="cert_id"
      :column-label="$i18n.t('Cert ID')"
    />

    <form-group-cert-file namespace="cert_file"
      :column-label="$i18n.t('Cert file')"
      :text="$i18n.t('The path to the certificate you submitted to Paypal.')"
    />

    <form-group-key-file namespace="key_file"
      :column-label="$i18n.t('Key file')"
      :text="$i18n.t('The path to the associated key of the certificate you submitted to Paypal.')"
    />

    <form-group-paypal-cert-file namespace="paypal_cert_file"
      :column-label="$i18n.t('Paypal cert file')"
      :text="$i18n.t('The path to the Paypal certificate you downloaded.')"
    />

    <form-group-email-address namespace="email_address"
      :column-label="$i18n.t('Email address')"
      :text="$i18n.t('The email address associated to your paypal account.')"
    />

    <form-group-payment-type namespace="payment_type"
      :column-label="$i18n.t('Payment type')"
    />

    <form-group-domains namespace="domains"
      :column-label="$i18n.t('Authorized domains')"
      :text="$i18n.t('Comma-separated list of domains that will be resolve with the correct IP addresses.')"
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
  FormGroupCertFile,
  FormGroupCertIdentifier,
  FormGroupCreateLocalAccount,
  FormGroupCurrency,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupEmailAddress,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupIdentityToken,
  FormGroupKeyFile,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupPaymentType,
  FormGroupPaypalCertFile,
  FormGroupSendEmailConfirmation,
  FormGroupTestMode,
} from './'

const components = {
  BaseForm,

  FormGroupCertFile,
  FormGroupCertIdentifier,
  FormGroupCreateLocalAccount,
  FormGroupCurrency,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupEmailAddress,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupIdentityToken,
  FormGroupKeyFile,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupPaymentType,
  FormGroupPaypalCertFile,
  FormGroupSendEmailConfirmation,
  FormGroupTestMode,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-paypal',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
