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

    <form-group-protocol-host-port :namespaces="['protocol', 'host', 'port']"
      :column-label="$i18n.t('File Path')"
    />

    <form-group-api-username namespace="api_username"
      :column-label="$i18n.t('API username (basic auth)')"
    />

    <form-group-api-password namespace="api_password"
      :column-label="$i18n.t('API password (basic auth)')"
    />

    <form-group-authentication-url namespace="authentication_url"
      :column-label="$i18n.t('Authentication URL')"
      :text="$i18n.t('Note : The URL is always prefixed by a slash (/).')"
    />

    <form-group-authorization-url namespace="authorization_url"
      :column-label="$i18n.t('Authorization URL')"
      :text="$i18n.t('Note: The URL is always prefixed by a slash (/).')"
    />

    <form-group-realms namespace="realms"
      :column-label="$i18n.t('Associated Realms')"
      :text="$i18n.t('Realms that will be associated with this source.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupApiUsername,
  FormGroupApiPassword,
  FormGroupAuthenticationUrl,
  FormGroupAuthorizationUrl,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupProtocolHostPort,
  FormGroupRealms,
} from './'

const components = {
  BaseForm,

  FormGroupApiUsername,
  FormGroupApiPassword,
  FormGroupAuthenticationUrl,
  FormGroupAuthorizationUrl,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupProtocolHostPort,
  FormGroupRealms,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-http',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
