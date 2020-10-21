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

    <form-group-banned-domains namespace="banned_domains"
      :column-label="$i18n.t('Comma-separated list of Banned Domains')"
      :text="$i18n.t('A comma-separated list of domains that are banned for email registration. Wildcards are accepted (*pfdemo.org). Banned domains are checked before allowed domains.')"
    />

    <form-group-allowed-domains namespace="allowed_domains"
      :column-label="$i18n.t('Comma-separated list of Allowed Domains')"
      :text="$i18n.t('A comma-separated list of domains that are allowed for email registration. Wildcards are accepted (*pfdemo.org). Allowed domains are checked after banned domains.')"
    />

    <form-group-email-activation-timeout :namespaces="['email_activation_timeout.interval', 'email_activation_timeout.unit']"
      :column-label="$i18n.t('Email Activation Timeout')"
      :text="$i18n.t('This is the delay given to a guest who registered by email confirmation to log into his email and click the activation link.')"
    />

    <form-group-allow-localdomain namespace="allow_localdomain"
      :column-label="$i18n.t('Allow Local Domain')"
      :text="$i18n.t('Accept self-registration with email address from the local domain.')"
    />

    <form-group-activation-domain namespace="activation_domain"
      :column-label="$i18n.t('Host in activation link')"
      :text="$i18n.t('Set this value if you want to change the hostname in the validation link. Changing this requires to restart haproxy to be fully effective.')"
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
  FormGroupActivationDomain,
  FormGroupAllowedDomains,
  FormGroupAllowLocaldomain,
  FormGroupAuthenticationRules,
  FormGroupBannedDomains,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupEmailActivationTimeout,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
} from './'

const components = {
  BaseForm,

  FormGroupActivationDomain,
  FormGroupAllowedDomains,
  FormGroupAllowLocaldomain,
  FormGroupAuthenticationRules,
  FormGroupBannedDomains,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupEmailActivationTimeout,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-email',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
