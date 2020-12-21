<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
    :isReadonly="id === 'default' && !isClone"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="!isNew && !isClone"
    />

    <form-group-ocsp-enable namespace="ocsp_enable"
      :column-label="$i18n.t('Enable')"
      :text="$i18n.t('Enable OCSP checking.')"
    />

    <form-group-ocsp-override-cert-url namespace="ocsp_override_cert_url"
      :column-label="$i18n.t('Override Responder URL')"
      :text="$i18n.t('Override the OCSP Responder URL from the certificate.')"
    />

    <form-group-ocsp-url namespace="ocsp_url"
      :column-label="$i18n.t('Responder URL')"
      :text="$i18n.t('The overridden OCSP Responder URL.')"
    />

    <form-group-ocsp-use-nonce namespace="ocsp_use_nonce"
      :column-label="$i18n.t('Use nonce')"
      :text="$i18n.t('If the OCSP Responder can not cope with nonce in the request, then it can be disabled here.')"
    />

    <form-group-ocsp-timeout namespace="ocsp_timeout"
      :column-label="$i18n.t('Response timeout')"
      :text="$i18n.t('Number of seconds to wait for the OCSP response. 0 uses system default.')"
    />

    <form-group-ocsp-softfail namespace="ocsp_softfail"
      :column-label="$i18n.t('Response softfail')"
      :text="$i18n.t(`Treat OCSP response errors as 'soft' failures and still accept the certificate.`)"
    />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupOcspEnable,
  FormGroupOcspOverrideCertUrl,
  FormGroupOcspUrl,
  FormGroupOcspUseNonce,
  FormGroupOcspTimeout,
  FormGroupOcspSoftfail
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupOcspEnable,
  FormGroupOcspOverrideCertUrl,
  FormGroupOcspUrl,
  FormGroupOcspUseNonce,
  FormGroupOcspTimeout,
  FormGroupOcspSoftfail
}

export const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
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
