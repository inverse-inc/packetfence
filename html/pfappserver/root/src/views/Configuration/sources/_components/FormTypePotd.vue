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

    <form-group-password-rotation namespace="password_rotation"
      :column-label="$i18n.t('Password rotation duration')"
      :text="$i18n.t('Period of time after the password must be rotated.')"
    />

    <form-group-password-email-update namespace="password_email_update"
      :column-label="$i18n.t('Email')"
      :text="$i18n.t('Email addresses to send the new generated password.')"
    />

    <form-group-password-length namespace="password_length"
      :column-label="$i18n.t('Password length')"
      :text="$i18n.t('The length of the password to generate.')"
    />

    <form-group-realms namespace="realms"
      :column-label="$i18n.t('Associated Realms')"
      :text="$i18n.t('Realms that will be associated with this source (for the portal/admin GUI/RADIUS post-auth, not for FreeRADIUS proxy).')"
    />

    <form-group-authentication-rules namespace="authentication_rules"
      :column-label="$i18n.t('Authentication Rules')"
    />

    <form-group-administration-rules namespace="administration_rules"
      :column-label="$i18n.t('Administration Rules')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAdministrationRules,
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupPasswordEmailUpdate,
  FormGroupPasswordLength,
  FormGroupPasswordRotation,
  FormGroupRealms,
} from './'

const components = {
  BaseForm,

  FormGroupAdministrationRules,
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupPasswordEmailUpdate,
  FormGroupPasswordLength,
  FormGroupPasswordRotation,
  FormGroupRealms,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-potd',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
