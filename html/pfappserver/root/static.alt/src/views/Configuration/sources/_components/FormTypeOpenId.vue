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

    <form-group-authorize-path namespace="authorize_path"
      :column-label="$i18n.t('API Authorize Path')"
    />

    <form-group-access-token-path namespace="access_token_path"
      :column-label="$i18n.t('API Token Path')"
    />

    <form-group-access-scope namespace="access_scope"
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

    <form-group-authentication-rules namespace="authentication_rules"
      :column-label="$i18n.t('Authentication Rules')"
    />

    <form-group-person-mappings namespace="person_mappings"
      :column-label="$i18n.t('User Mappings')"
    />

    <form-group-username-attribute namespace="username_attribute"
      :column-label="$i18n.t('Username Attribute')"
      :text="$i18n.t('Main reference attribute that contain the username.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAccessScope,
  FormGroupAccessTokenPath,
  FormGroupAuthenticationRules,
  FormGroupAuthorizePath,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupPersonMappings,
  FormGroupProtectedResourceUrl,
  FormGroupRedirectUrl,
  FormGroupSite,
  FormGroupUsernameAttribute,
} from './'

const components = {
  BaseForm,

  FormGroupAccessScope,
  FormGroupAccessTokenPath,
  FormGroupAuthenticationRules,
  FormGroupAuthorizePath,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupPersonMappings,
  FormGroupProtectedResourceUrl,
  FormGroupRedirectUrl,
  FormGroupSite,
  FormGroupUsernameAttribute,

}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-open-id',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
