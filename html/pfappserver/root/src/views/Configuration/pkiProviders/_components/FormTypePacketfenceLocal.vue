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
      :column-label="$i18n.t('Client certificate file')"
      :title="$i18n.t('Upload client certificate file')"
      :text="$i18n.t('Client certificate that will be used to generate the p12.')"
    />

    <form-group-client-key-path namespace="client_key_path"
      :column-label="$i18n.t('Client key file')"
      :title="$i18n.t('Upload client key file')"
      :text="$i18n.t('Client key that will be used to generate the p12.')"
    />

    <form-group-ca-cert-path namespace="ca_cert_path"
      :column-label="$i18n.t('CA certificate file')"
      :title="$i18n.t('Upload CA certificate file')"
      :text="$i18n.t('CA certificate used to generate client certificate/key combination.')"
    />

    <b-form-group label-cols="3">
      <div class="d-flex align-items-center">
        <button-pki-import :modes="['ca']"
                           :modal-title="$i18n.t('Import CA certificate from PacketFence PKI')"
                           @import="onPkiImportCa"
        />
      </div>
    </b-form-group>

    <form-group-server-cert-path namespace="server_cert_path"
      :column-label="$i18n.t('Server certificate file')"
      :title="$i18n.t('Upload server certificate file')"
      :text="$i18n.t('RADIUS server authentication certificate.')"
    />

    <b-form-group label-cols="3">
      <button-pki-import :modes="['public']"
                         :modal-title="$i18n.t('Import RADIUS server certificate from PacketFence PKI')"
                         @import="onPkiImportServerCertificate"
      />
    </b-form-group>
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
import ButtonPkiImport from '../../pki/_components/ButtonPkiImport'

const components = {
  BaseForm,
  ButtonPkiImport,

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
