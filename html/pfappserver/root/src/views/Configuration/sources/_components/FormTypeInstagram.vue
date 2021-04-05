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

    <form-group-client-identifier namespace="client_id"
      :column-label="$i18n.t('App ID')"
    />

    <form-group-client-secret namespace="client_secret"
      :column-label="$i18n.t('App Secret')"
    />

    <form-group-site namespace="site"
      :column-label="$i18n.t('API URL')"
    />

    <form-group-access-token-path namespace="access_token_path"
      :column-label="$i18n.t('API Token Path')"
    />

    <form-group-access-token-param namespace="access_token_param"
      :column-label="$i18n.t('Access Token Parameter')"
    />

    <form-group-scope namespace="scope"
      :column-label="$i18n.t('Scope')"
      :text="$i18n.t('The permissions the application requests.')"
    />

    <form-group-protected-resource-url namespace="protected_resource_url"
      :column-label="$i18n.t('API URL of logged user')"
    />

    <form-group-redirect-url namespace="redirect_url"
      :column-label="$i18n.t('Portal URL')"
      :text="$i18n.t('The hostname must be the one of your captive portal.')"
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

    <form-group-local-account-expiration namespace="local_account_expiration"
      :column-label="$i18n.t('Local account expiration')"
      :text="$i18n.t('The amount of time after which the local account will expire. A value of 0 will use the access duration that is found via the authentication rules for the user.')"
    />

    <form-group-authentication-rules namespace="authentication_rules"
      :column-label="$i18n.t('Authentication Rules')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAccessTokenParam,
  FormGroupAccessTokenPath,
  FormGroupAuthenticationRules,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountExpiration,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupProtectedResourceUrl,
  FormGroupRedirectUrl,
  FormGroupScope,
  FormGroupSite,
} from './'

const components = {
  BaseForm,

  FormGroupAccessTokenParam,
  FormGroupAccessTokenPath,
  FormGroupAuthenticationRules,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountExpiration,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupProtectedResourceUrl,
  FormGroupRedirectUrl,
  FormGroupScope,
  FormGroupSite,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-instagram',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
