<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >

    <!--
      @type: AD
    -->
    <template v-if="form.type === 'AD'">
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

    </template>


    <!--
      @type: Htpasswd
    -->
    <template v-else-if="form.type === 'Htpasswd'">
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Name')"
        :disabled="!isNew && !isClone"
      />

      <form-group-description namespace="description"
        :column-label="$i18n.t('Description')"
      />

      <form-group-path namespace="path"
        :column-label="$i18n.t('File Path')"
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

    </template>

    <b-container class="my-5" v-else>
      <b-row class="justify-content-md-center text-secondary">
        <b-col cols="12" md="auto">
          <b-media v-if="isLoading">
            <template v-slot:aside>
              <icon name="circle-notch" scale="2" spin></icon>
            </template>
            <h4>{{ $t('Building Form') }}</h4>
            <p class="font-weight-light">{{ $t('Hold on a moment while we render it...') }}</p>
          </b-media>
          <b-media v-else>
            <template v-slot:aside><icon name="question-circle" scale="2"></icon></template>
            <h4>{{ $t('Unhandled source type') }}</h4>
          </b-media>
        </b-col>
      </b-row>
    </b-container>

  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import { useForm, useFormProps } from '../_composables/useForm'

import {
  FormGroupAuthenticationRules,
  FormGroupAdministrationRules,
  FormGroupBaseDn,
  FormGroupBindDn,
  FormGroupConnectionTimeout,
  FormGroupDescription,
  FormGroupEmailAttribute,
  FormGroupHostPortEncryption,
  FormGroupIdentifier,
  FormGroupPassword,
  FormGroupPath,
  FormGroupReadTimeout,
  FormGroupRealms,
  FormGroupScope,
  FormGroupSearchAttributes,
  FormGroupSearchAttributesAppend,
  FormGroupUsernameAttribute,
  FormGroupWriteTimeout,
} from './'

const components = {
  BaseForm,

  FormGroupAuthenticationRules,
  FormGroupAdministrationRules,
  FormGroupBaseDn,
  FormGroupBindDn,
  FormGroupConnectionTimeout,
  FormGroupDescription,
  FormGroupEmailAttribute,
  FormGroupHostPortEncryption,
  FormGroupIdentifier,
  FormGroupPassword,
  FormGroupPath,
  FormGroupReadTimeout,
  FormGroupRealms,
  FormGroupScope,
  FormGroupSearchAttributes,
  FormGroupSearchAttributesAppend,
  FormGroupUsernameAttribute,
  FormGroupWriteTimeout,
}

export const props = useFormProps

export const setup = (props, context) => useForm(props, context)

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
