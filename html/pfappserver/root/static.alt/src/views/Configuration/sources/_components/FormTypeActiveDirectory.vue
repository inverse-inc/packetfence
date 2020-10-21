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

    <form-group-host-port-encryption :namespaces="['host', 'port', 'encryption']"
      :column-label="$i18n.t('Host')"
    />

    <form-group-connection-timeout namespace="connection_timeout"
      :column-label="$i18n.t('Connection timeout')"
      :text="$i18n.t('LDAP connection Timeout.')"
    />

    <form-group-write-timeout namespace="write_timeout"
      :column-label="$i18n.t('Request timeout')"
      :text="$i18n.t('LDAP request timeout.')"
    />

    <form-group-read-timeout namespace="read_timeout"
      :column-label="$i18n.t('Response timeout')"
      :text="$i18n.t('LDAP response timeout.')"
    />

    <form-group-base-dn namespace="basedn"
      :column-label="$i18n.t('Base DN')"
    />

    <form-group-scope namespace="scope"
      :column-label="$i18n.t('Scope')"
    />

    <form-group-username-attribute namespace="usernameattribute"
      :column-label="$i18n.t('Username Attribute')"
      :text="$i18n.t('Main reference attribute that contain the username.')"
    />

    <form-group-search-attributes namespace="searchattributes"
      :column-label="$i18n.t('Search Attributes')"
      :text="$i18n.t('Other attributes that can be used as the username (requires to restart the radiusd service to be effective).')"
    />

    <form-group-search-attributes-append namespace="append_to_searchattributes"
      :column-label="$i18n.t('Append search attributes ldap filter')"
      :text="$i18n.t('Append this ldap filter to the generated generated ldap filter generated for the search attributes.')"
    />

    <form-group-email-attribute namespace="email_attribute"
      :column-label="$i18n.t('Email Attribute')"
      :text="$i18n.t('LDAP attribute name that stores the email address against which the filter will match.')"
    />

    <form-group-bind-dn namespace="binddn"
      :column-label="$i18n.t('Bind DN')"
      :text="$i18n.t('Leave this field empty if you want to perform an anonymous bind.')"
    />

    <form-group-password namespace="password"
      :column-label="$i18n.t('Password')"
    />

    <form-group-cache-match namespace="cache_match"
      :column-label="$i18n.t('Cache match')"
      :text="$i18n.t('Will cache results of matching a rule.')"
    />

    <form-group-monitor namespace="monitor"
      :column-label="$i18n.t('Monitor')"
      :text="$i18n.t('Do you want to monitor this source?')"
    />

    <form-group-shuffle namespace="shuffle"
      :column-label="$i18n.t('Shuffle')"
      :text="$i18n.t('Randomly choose LDAP server to query.')"
    />

    <form-group-realms namespace="realms"
      :column-label="$i18n.t('Associated Realms')"
      :text="$i18n.t('Realms that will be associated with this source.')"
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
  FormGroupBaseDn,
  FormGroupBindDn,
  FormGroupCacheMatch,
  FormGroupConnectionTimeout,
  FormGroupDescription,
  FormGroupEmailAttribute,
  FormGroupHostPortEncryption,
  FormGroupIdentifier,
  FormGroupMonitor,
  FormGroupPassword,
  FormGroupReadTimeout,
  FormGroupRealms,
  FormGroupScope,
  FormGroupSearchAttributes,
  FormGroupSearchAttributesAppend,
  FormGroupShuffle,
  FormGroupUsernameAttribute,
  FormGroupWriteTimeout,
} from './'

const components = {
  BaseForm,

  FormGroupAdministrationRules,
  FormGroupAuthenticationRules,
  FormGroupBaseDn,
  FormGroupBindDn,
  FormGroupCacheMatch,
  FormGroupConnectionTimeout,
  FormGroupDescription,
  FormGroupEmailAttribute,
  FormGroupHostPortEncryption,
  FormGroupIdentifier,
  FormGroupMonitor,
  FormGroupPassword,
  FormGroupReadTimeout,
  FormGroupRealms,
  FormGroupScope,
  FormGroupSearchAttributes,
  FormGroupSearchAttributesAppend,
  FormGroupShuffle,
  FormGroupUsernameAttribute,
  FormGroupWriteTimeout,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-active-directory',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
