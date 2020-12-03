<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('PKI Provider Name')"
      :disabled="!isNew && !isClone"
    />

    <form-group-url namespace="url"
      :column-label="$i18n.t('URL')"
      :text="$i18n.t('The url used to connect to the SCEP PKI service.')"
    />

    <form-group-username namespace="username"
      :column-label="$i18n.t('Username')"
      :text="$i18n.t('Username to connect to the SCEP PKI Service.')"
    />

    <form-group-password namespace="password"
      :column-label="$i18n.t('Password')"
      :text="$i18n.t('Password for the username filled in above.')"
    />

    <form-group-country namespace="country"
      :column-label="$i18n.t('Country')"
      :text="$i18n.t('Country for the certificate.')"
    />

    <form-group-state namespace="state"
      :column-label="$i18n.t('State')"
      :text="$i18n.t('State for the certificate.')"
    />

    <form-group-locality namespace="locality"
      :column-label="$i18n.t('Locality')"
      :text="$i18n.t('Locality for the certificate.')"
    />

    <form-group-organization namespace="organization"
      :column-label="$i18n.t('Organization')"
      :text="$i18n.t('Organization for the certificate.')"
    />

    <form-group-organizational-unit namespace="organizational_unit"
      :column-label="$i18n.t('Organizational unit')"
      :text="$i18n.t('Organizational unit for the certificate.')"
    />

    <form-group-common-name-attribute namespace="cn_attribute"
      :column-label="$i18n.t('Common Name Attribute')"
      :text="$i18n.t('Defines what attribute of the node to use as the common name during the certificate generation.')"
    />

    <form-group-common-name-format namespace="cn_format"
      :column-label="$i18n.t('Common Name Format')"
      :text="$i18n.t('Defines how the common name will be formated. %s will expand to the defined Common Name Attribute value.')"
    />

    <form-group-ca-cert-path namespace="ca_cert_path"
      :column-label="$i18n.t('CA cert path')"
      :text="$i18n.t('Path of the CA certificate used to generate client certificate/key combination.')"
    />

    <form-group-server-cert-path namespace="server_cert_path"
      :column-label="$i18n.t('Server cert path')"
      :text="$i18n.t('Path of the RADIUS server authentication certificate.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupCaCertPath,
  FormGroupCommonNameAttribute,
  FormGroupCommonNameFormat,
  FormGroupCountry,
  FormGroupIdentifier,
  FormGroupLocality,
  FormGroupOrganization,
  FormGroupOrganizationalUnit,
  FormGroupPassword,
  FormGroupServerCertPath,
  FormGroupState,
  FormGroupUrl,
  FormGroupUsername
} from './'

const components = {
  BaseForm,

  FormGroupCaCertPath,
  FormGroupCommonNameAttribute,
  FormGroupCommonNameFormat,
  FormGroupCountry,
  FormGroupIdentifier,
  FormGroupLocality,
  FormGroupOrganization,
  FormGroupOrganizationalUnit,
  FormGroupPassword,
  FormGroupServerCertPath,
  FormGroupState,
  FormGroupUrl,
  FormGroupUsername
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-packetfence-local',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
