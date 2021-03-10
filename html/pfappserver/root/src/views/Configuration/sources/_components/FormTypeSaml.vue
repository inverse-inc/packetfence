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
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAuthorizationSourceIdentifier,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupIdentityProviderCaCertPath,
  FormGroupIdentityProviderCertPath,
  FormGroupIdentityProviderEntityIdentifier,
  FormGroupIdentityProviderMetadataPath,
  FormGroupServiceProviderEntityIdentifier,
  FormGroupServiceProviderCertPath,
  FormGroupServiceProviderKeyPath,
  FormGroupUsernameAttribute,
} from './'

const components = {
  BaseForm,

  FormGroupAuthorizationSourceIdentifier,
  FormGroupDescription,
  FormGroupIdentifier,
  FormGroupIdentityProviderCaCertPath,
  FormGroupIdentityProviderCertPath,
  FormGroupIdentityProviderEntityIdentifier,
  FormGroupIdentityProviderMetadataPath,
  FormGroupServiceProviderEntityIdentifier,
  FormGroupServiceProviderCertPath,
  FormGroupServiceProviderKeyPath,
  FormGroupUsernameAttribute,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-saml',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
