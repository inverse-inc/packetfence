<template>
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

  <form-group-authentication-rules namespace="authentication_rules"
    :column-label="$i18n.t('Authentication Rules')"
  />
</template>
<script>
import {
  FormGroupAccessTokenPath,
  FormGroupAuthenticationRules,
  FormGroupAuthorizePath,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupIdentifier,
  FormGroupProtectedResourceUrl,
  FormGroupRedirectUrl,
  FormGroupSite,
} from './'

const components = {
  FormGroupAccessTokenPath,
  FormGroupAuthenticationRules,
  FormGroupAuthorizePath,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupDescription,
  FormGroupDomains,
  FormGroupIdentifier,
  FormGroupProtectedResourceUrl,
  FormGroupRedirectUrl,
  FormGroupSite,
}

const props = {
  isNew: {
    type: Boolean
  },
  isClone: {
    type: Boolean
  }
}

// @vue/component
export default {
  name: 'source-form-twitter',
  inheritAttrs: false,
  components,
  props
}
</script>
