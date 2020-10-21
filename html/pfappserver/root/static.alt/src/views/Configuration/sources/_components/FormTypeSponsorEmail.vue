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

    <form-group-sources namespace="sources"
      :column-label="$i18n.t('Associated Sources')"
      :text="$i18n.t('Sources that will be associated with this source (For the Sponsor).\nWith no source specified, all internal and external sources will be used.')"
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
  FormGroupAllowLocaldomain,
  FormGroupAuthenticationRules,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupSources,
} from './'

const components = {
  BaseForm,

  FormGroupActivationDomain,
  FormGroupAllowLocaldomain,
  FormGroupAuthenticationRules,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupHashPasswords,
  FormGroupIdentifier,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupSources,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-sponsor-email',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
