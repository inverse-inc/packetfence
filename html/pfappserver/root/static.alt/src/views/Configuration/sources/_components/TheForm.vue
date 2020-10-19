<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >

    <!--
      @type: AD|LDAP
    -->
    <template v-if="['AD', 'LDAP'].includes(form.type)">
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
    </template>


    <!--
      @type: Authorization
    -->
    <template v-else-if="form.type === 'Authorization'">
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Name')"
        :disabled="!isNew && !isClone"
      />

      <form-group-description namespace="description"
        :column-label="$i18n.t('Description')"
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
    </template>


    <!--
      @type: EAPTLS
    -->
    <template v-else-if="form.type === 'EAPTLS'">
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Name')"
        :disabled="!isNew && !isClone"
      />

      <form-group-description namespace="description"
        :column-label="$i18n.t('Description')"
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


    <!--
      @type: HTTP
    -->
    <template v-else-if="form.type === 'HTTP'">
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


    <!--
      @type: Kerberos
    -->
    <template v-else-if="form.type === 'Kerberos'">
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Name')"
        :disabled="!isNew && !isClone"
      />

      <form-group-description namespace="description"
        :column-label="$i18n.t('Description')"
      />

      <form-group-host namespace="host"
        :column-label="$i18n.t('Host')"
      />

      <form-group-authenticate-realm namespace="authenticate_realm"
        :column-label="$i18n.t('Realm to use to authenticate')"
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


    <!--
      @type: Potd
    -->
    <template v-else-if="form.type === 'Potd'">
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
    </template>


    <!--
      @type: RADIUS
    -->
    <template v-else-if="form.type === 'RADIUS'">
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Name')"
        :disabled="!isNew && !isClone"
      />

      <form-group-description namespace="description"
        :column-label="$i18n.t('Description')"
      />

      <form-group-host namespace="host"
        :column-label="$i18n.t('Host')"
      />

      <form-group-port namespace="port"
        :column-label="$i18n.t('Port')"
        :text="$i18n.t('If you use this source in the realm configuration the accounting port will be this port + 1.')"
      />

      <form-group-secret namespace="secret"
        :column-label="$i18n.t('Secret')"
      />

      <form-group-timeout namespace="timeout"
        :column-label="$i18n.t('Timeout')"
      />

      <form-group-monitor namespace="monitor"
        :column-label="$i18n.t('Monitor')"
        :text="$i18n.t('Do you want to monitor this source?')"
      />

      <form-group-options namespace="options"
        :column-label="$i18n.t('Options')"
        :text="$i18n.t('Define options for FreeRADIUS home_server definition (if you use the source in the realm configuration). Need a radiusd restart.')"
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
    </template>


    <!--
      @type: SAML
    -->
    <template v-else-if="form.type === 'SAML'">
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Name')"
        :disabled="!isNew && !isClone"
      />

      <form-group-description namespace="description"
        :column-label="$i18n.t('Description')"
      />

      <form-group-service-provider-entity-identifier namespace="sp_entity_id"
        :column-label="$i18n.t('Service Provider entity ID')"
      />

      <form-group-service-provider-key-path namespace="sp_key_path"
        :column-label="$i18n.t('Path to Service Provider key (x509)')"
      />

      <form-group-service-provider-cert-path namespace="sp_cert_path"
        :column-label="$i18n.t('Path to Service Provider cert (x509)')"
      />

      <form-group-identity-provider-entity-identifier namespace="idp_entity_id"
        :column-label="$i18n.t('Identity Provider entity ID')"
      />

      <form-group-identity-provider-metadata-path namespace="idp_metadata_path"
        :column-label="$i18n.t('Path to Identity Provider metadata')"
      />

      <form-group-identity-provider-cert-path namespace="idp_cert_path"
        :column-label="$i18n.t('Path to Identity Provider cert (x509)')"
      />

      <form-group-identity-provider-ca-cert-path namespace="idp_ca_cert_path"
        :column-label="$i18n.t('Path to Identity Provider CA cert (x509)')"
        :text="$i18n.t('If your Identity Provider uses a self-signed certificate, put the path to its certificate here instead.')"
      />

      <form-group-username-attribute namespace="username_attribute"
        :column-label="$i18n.t('Username Attribute')"
        :text="$i18n.t('Main reference attribute that contain the username.')"
      />

      <form-group-authorization-source-identifier namespace="authorization_source_id"
        :column-label="$i18n.t('Authorization source')"
        :text="$i18n.t('The source to use for authorization (rule matching).')"
      />
    </template>


    <!--
      @type: Clickatell
    -->
    <template v-else-if="form.type === 'Clickatell'">
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Name')"
        :disabled="!isNew && !isClone"
      />

      <form-group-description namespace="description"
        :column-label="$i18n.t('Description')"
      />

      <form-group-api-key namespace="api_key"
        :column-label="$i18n.t('Clickatell API Key.')"
      />

      <form-group-message namespace="message"
        :column-label="$i18n.t('SMS text message ($pin will be replaced by the PIN number)')"
      />

      <form-group-pin-code-length namespace="pin_code_length"
        :column-label="$i18n.t('PIN length')"
        :text="$i18n.t('The amount of digits of the PIN number.')"
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
    </template>


    <!--
      @type: Email
    -->
    <template v-else-if="form.type === 'Email'">
      <form-group-identifier namespace="id"
        :column-label="$i18n.t('Name')"
        :disabled="!isNew && !isClone"
      />

      <form-group-description namespace="description"
        :column-label="$i18n.t('Description')"
      />

      <form-group-banned-domains namespace="banned_domains"
        :column-label="$i18n.t('Comma-separated list of Banned Domains')"
        :text="$i18n.t('A comma-separated list of domains that are banned for email registration. Wildcards are accepted (*pfdemo.org). Banned domains are checked before allowed domains.')"
      />

      <form-group-allowed-domains namespace="allowed_domains"
        :column-label="$i18n.t('Comma-separated list of Allowed Domains')"
        :text="$i18n.t('A comma-separated list of domains that are allowed for email registration. Wildcards are accepted (*pfdemo.org). Allowed domains are checked after banned domains.')"
      />

      <form-group-email-activation-timeout :namespaces="['email_activation_timeout.interval', 'email_activation_timeout.unit']"
        :column-label="$i18n.t('Email Activation Timeout')"
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
    </template>
<!--
        :column-label="$i18n.t('')"
        :text="$i18n.t('')"

-->

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
  FormGroupActivationDomain,
  FormGroupAdministrationRules,
  FormGroupAllowedDomains,
  FormGroupAllowLocaldomain,
  FormGroupApiKey,
  FormGroupAuthenticateRealm,
  FormGroupAuthenticationRules,
  FormGroupAuthorizationSourceIdentifier,
  FormGroupBannedDomains,
  FormGroupBaseDn,
  FormGroupBindDn,
  FormGroupCacheMatch,
  FormGroupConnectionTimeout,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupEmailActivationTimeout,
  FormGroupEmailAttribute,
  FormGroupHashPasswords,
  FormGroupHost,
  FormGroupHostPortEncryption,
  FormGroupIdentifier,
  FormGroupIdentityProviderCaCertPath,
  FormGroupIdentityProviderCertPath,
  FormGroupIdentityProviderEntityIdentifier,
  FormGroupIdentityProviderMetadataPath,
  FormGroupLocalAccountLogins,
  FormGroupMessage,
  FormGroupMonitor,
  FormGroupOptions,
  FormGroupPassword,
  FormGroupPasswordEmailUpdate,
  FormGroupPasswordLength,
  FormGroupPasswordRotation,
  FormGroupPath,
  FormGroupPinCodeLength,
  FormGroupPort,
  FormGroupProtocolHostPort,
  FormGroupReadTimeout,
  FormGroupRealms,
  FormGroupScope,
  FormGroupSearchAttributes,
  FormGroupSearchAttributesAppend,
  FormGroupSecret,
  FormGroupServiceProviderEntityIdentifier,
  FormGroupServiceProviderCertPath,
  FormGroupServiceProviderKeyPath,
  FormGroupShuffle,
  FormGroupTimeout,
  FormGroupUsernameAttribute,
  FormGroupWriteTimeout,
} from './'

const components = {
  BaseForm,

  FormGroupActivationDomain,
  FormGroupAdministrationRules,
  FormGroupAllowedDomains,
  FormGroupAllowLocaldomain,
  FormGroupApiKey,
  FormGroupAuthenticateRealm,
  FormGroupAuthenticationRules,
  FormGroupAuthorizationSourceIdentifier,
  FormGroupBannedDomains,
  FormGroupBaseDn,
  FormGroupBindDn,
  FormGroupCacheMatch,
  FormGroupConnectionTimeout,
  FormGroupCreateLocalAccount,
  FormGroupDescription,
  FormGroupEmailActivationTimeout,
  FormGroupEmailAttribute,
  FormGroupHashPasswords,
  FormGroupHost,
  FormGroupHostPortEncryption,
  FormGroupIdentifier,
  FormGroupIdentityProviderCaCertPath,
  FormGroupIdentityProviderCertPath,
  FormGroupIdentityProviderEntityIdentifier,
  FormGroupIdentityProviderMetadataPath,
  FormGroupLocalAccountLogins,
  FormGroupMessage,
  FormGroupMonitor,
  FormGroupOptions,
  FormGroupPassword,
  FormGroupPasswordEmailUpdate,
  FormGroupPasswordLength,
  FormGroupPasswordRotation,
  FormGroupPath,
  FormGroupPinCodeLength,
  FormGroupPort,
  FormGroupProtocolHostPort,
  FormGroupReadTimeout,
  FormGroupRealms,
  FormGroupScope,
  FormGroupSearchAttributes,
  FormGroupSearchAttributesAppend,
  FormGroupSecret,
  FormGroupServiceProviderEntityIdentifier,
  FormGroupServiceProviderCertPath,
  FormGroupServiceProviderKeyPath,
  FormGroupShuffle,
  FormGroupTimeout,
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
