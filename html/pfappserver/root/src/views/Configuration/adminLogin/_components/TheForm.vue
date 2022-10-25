<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-sso-status namespace="sso_status"
      :column-label="$i18n.t('SSO Status')"
    />

    <form-group-sso-authorize-path namespace="sso_authorize_path"
      :column-label="$i18n.t('SSO Authorize Path')"
    />

    <form-group-sso-base-url namespace="sso_base_url"
      :column-label="$i18n.t('SSO Base URL')"
    />

    <form-group-sso-login-path namespace="sso_login_path"
      :column-label="$i18n.t('SSO Login Path')"
    />

    <form-group-sso-login-text namespace="sso_login_text"
      :column-label="$i18n.t('SSO Login Button Text')"
    />

    <form-group-allow-username-password namespace="allow_username_password"
      :column-label="$i18n.t('Allow SSO username and password')"
    />

  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAllowUsernamePassword,
  FormGroupSsoAuthorizePath,
  FormGroupSsoBaseUrl,
  FormGroupSsoLoginPath,
  FormGroupSsoLoginText,
  FormGroupSsoStatus,
} from './'

const components = {
  BaseForm,

  FormGroupAllowUsernamePassword,
  FormGroupSsoAuthorizePath,
  FormGroupSsoBaseUrl,
  FormGroupSsoLoginPath,
  FormGroupSsoLoginText,
  FormGroupSsoStatus,
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {

  const schema = computed(() => schemaFn(props))

  return {
    schema
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

