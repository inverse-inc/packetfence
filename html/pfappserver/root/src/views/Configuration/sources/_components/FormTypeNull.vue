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

    <form-group-email-required namespace="email_required"
                               :column-label="$i18n.t('Email required')"
                               enabled-value="yes"
                               disabled-value="no"
    />

    <form-group-create-local-account namespace="create_local_account"
                                     :column-label="$i18n.t('Create Local Account')"
                                     :text="$i18n.t('Create a local account on the PacketFence system based on the username provided.')"
                                     enabled-value="yes"
                                     disabled-value="no"
    />

    <form-group-hash-passwords namespace="hash_passwords"
                               :column-label="$i18n.t('Database passwords hashing method')"
                               :text="$i18n.t('The algorithm used to hash the passwords in the database. This will only affect newly created or reset passwords.')"
    />

    <form-group-password-length namespace="password_length"
                                :column-label="$i18n.t('Password length')"
                                :text="$i18n.t('The length of the password to generate.')"
    />

    <form-group-local-account-logins namespace="local_account_logins"
                                     :column-label="$i18n.t('Amount of logins for the local account')"
                                     :text="$i18n.t('The amount of times the local account can be used after it is created. 0 means infinite.')"
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
import {BaseForm} from '@/components/new/'
import {
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupEmailRequired,
  FormGroupCreateLocalAccount,
  FormGroupHashPasswords,
  FormGroupLocalAccountExpiration,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupIdentifier,
} from './'

const components = {
  BaseForm,

  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupEmailRequired,
  FormGroupCreateLocalAccount,
  FormGroupHashPasswords,
  FormGroupLocalAccountExpiration,
  FormGroupLocalAccountLogins,
  FormGroupPasswordLength,
  FormGroupIdentifier,
}

import {useForm as setup, useFormProps as props} from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-null',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
