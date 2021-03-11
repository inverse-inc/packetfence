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

    <form-group-client-cert-path namespace="client_cert_path"
      :column-label="$i18n.t('Client cert path')"
      :text="$i18n.t('Path of the client cert that will be used to generate the p12.')"
    />

    <form-group-client-key-path namespace="client_key_path"
      :column-label="$i18n.t('Client key path')"
      :text="$i18n.t('Path of the client key that will be used to generate the p12.')"
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
  FormGroupClientCertPath,
  FormGroupClientKeyPath,
  FormGroupIdentifier,
  FormGroupServerCertPath
} from './'

const components = {
  BaseForm,

  FormGroupCaCertPath,
  FormGroupClientCertPath,
  FormGroupClientKeyPath,
  FormGroupIdentifier,
  FormGroupServerCertPath
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
