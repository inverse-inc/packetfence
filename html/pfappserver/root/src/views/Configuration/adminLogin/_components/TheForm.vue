<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-sso-status namespace="sso_status"
                           :column-label="$i18n.t('SSO Status')"
                           :text="$i18n.t('Whether or not SSO should be enabled for the admin interface login. Changing this requires to restart the api-frontend service.')"
                           enabled-value="enabled"
                           disabled-value="disabled"
    />

    <form-group-sso-base-url namespace="sso_base_url"
                             :column-label="$i18n.t('SSO Base URL')"
                             :text="$i18n.t('The base URL of the SSO server. If left empty, it will default to the hostname and domain (`hostname.domain`) defined in the general settings. Change this if your portal is bound to another domain name.')"
    />

    <form-group-sso-login-path namespace="sso_login_path"
                               :column-label="$i18n.t('SSO Login Path')"
                               :text="$i18n.t('The path to redirect the user to in order to perform the SSO login.')"
    />

    <form-group-sso-login-text namespace="sso_login_text"
                               :column-label="$i18n.t('SSO Login Button Text')"
                               :text="$i18n.t('The text to display in the SSO login button in the admin interface.')"
    />

    <form-group-sso-authorize-path namespace="sso_authorize_path"
                                   :column-label="$i18n.t('SSO Authorize Path')"
                                   :text="$i18n.t('The path to obtain the authorization data after the SSO.')"
    />

    <form-group-allow-username-password namespace="allow_username_password"
                                        :column-label="$i18n.t('Allow SSO username and password')"
                                        :text="$i18n.t('Whether or not username/password authentication is allowed for the admin interface login. Disabling this will force users to use SSO. Changing this requires to restart the api-frontend service.')"
                                        enabled-value="enabled"
                                        disabled-value="disabled"
    />

  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
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

