<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-sso-status namespace="sso_status"
                           :column-label="$i18n.t('SSO Status')"
                           :text="$i18n.t('Whether or not sponsors validating a guest request and users logging into the self-service portal can authenticate through single sign-on. The SSO login path must be served by a connection profile whose root module is a SelfRegSSO module containing the SAML or OAuth source to use.')"
                           enabled-value="enabled"
                           disabled-value="disabled"
    />

    <form-group-sso-base-url namespace="sso_base_url"
                             :column-label="$i18n.t('SSO Base URL')"
                             :text="$i18n.t('The base URL of the portal serving the SSO login path. If left empty, it will default to the hostname and domain (`hostname.domain`) defined in the general settings.')"
    />

    <form-group-sso-login-path namespace="sso_login_path"
                               :column-label="$i18n.t('SSO Login Path')"
                               :text="$i18n.t('The portal path the user is redirected to in order to perform the single sign-on. A connection profile with a URI filter on this path must select the SelfRegSSO root module.')"
    />

    <form-group-sso-login-text namespace="sso_login_text"
                               :column-label="$i18n.t('SSO Login Button Text')"
                               :text="$i18n.t('The text of the single sign-on button on the sponsor and self-service login pages.')"
    />

    <form-group-sso-callback-allowed-hosts namespace="sso_callback_allowed_hosts"
                                           :column-label="$i18n.t('SSO Callback Allowed Hosts')"
                                           :text="$i18n.t('Comma-separated hostnames the single sign-on flow may redirect back to with the token. The host of the SSO base URL, this server hostname.domain and the activation domains of the sponsor sources are always allowed.')"
    />

    <form-group-allow-username-password namespace="allow_username_password"
                                        :column-label="$i18n.t('Allow username and password')"
                                        :text="$i18n.t('Whether the username/password form is still offered on the sponsor and self-service login pages when SSO is enabled. Disabling this forces single sign-on.')"
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
  FormGroupSsoBaseUrl,
  FormGroupSsoCallbackAllowedHosts,
  FormGroupSsoLoginPath,
  FormGroupSsoLoginText,
  FormGroupSsoStatus,
} from './'

const components = {
  BaseForm,

  FormGroupAllowUsernamePassword,
  FormGroupSsoBaseUrl,
  FormGroupSsoCallbackAllowedHosts,
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
