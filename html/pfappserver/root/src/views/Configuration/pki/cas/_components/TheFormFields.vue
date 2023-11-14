<template>
  <div>
    <form-group-identifier v-if="!isResign && !isNew && !isClone"
      namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="!isNew && !isClone"
    />

    <form-group-cn namespace="cn"
      :column-label="$i18n.t('Common Name')"
      :disabled="!isResign && !isNew && !isClone"
    />
    <form-group-mail namespace="mail"
      :column-label="$i18n.t('Email')"
      :disabled="!isResign && !isNew && !isClone"
    />
    <form-group-organisational-unit namespace="organisational_unit"
      :column-label="$i18n.t('Organisational Unit')"
      :disabled="!isResign && !isNew && !isClone"
    />
    <form-group-organisation namespace="organisation"
      :column-label="$i18n.t('Organisation')"
      :disabled="!isResign && !isNew && !isClone"
      :api-feedback="apiFeedback"
    />
    <form-group-country namespace="country"
      :column-label="$i18n.t('Country')"
      :disabled="!isResign && !isNew && !isClone"
      :api-feedback="apiFeedback"
    />
    <form-group-state namespace="state"
      :column-label="$i18n.t('State or Province')"
      :disabled="!isResign && !isNew && !isClone"
      :api-feedback="apiFeedback"
    />
    <form-group-locality namespace="locality"
      :column-label="$i18n.t('Locality')"
      :disabled="!isResign && !isNew && !isClone"
      :api-feedback="apiFeedback"
    />
    <form-group-street-address namespace="street_address"
      :column-label="$i18n.t('Street Address')"
      :disabled="!isResign && !isNew && !isClone"
    />
    <!-- temporarily hidden
    <form-group-postal-code namespace="postal_code"
      :column-label="$i18n.t('Postal Code')"
      :disabled="!isResign && !isNew && !isClone"
    />
    -->
    <form-group-key-type namespace="key_type"
      :column-label="$i18n.t('Key type')"
      :disabled="isResign || (!isNew && !isClone)"
    />
    <form-group-key-size namespace="key_size"
      :column-label="$i18n.t('Key size')"
      :disabled="isResign || (!isNew && !isClone)"
      :options="keySizeOptions"
    />
    <form-group-digest namespace="digest"
      :column-label="$i18n.t('Digest')"
      :disabled="!isResign && !isNew && !isClone"
    />
    <form-group-key-usage namespace="key_usage"
      :column-label="$i18n.t('Key usage')"
      :text="$i18n.t('Optional. One or many of: digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly, decipherOnly.')"
      :disabled="!isResign && !isNew && !isClone"
    />
    <form-group-extended-key-usage namespace="extended_key_usage"
      :column-label="$i18n.t('Extended key usage')"
      :text="$i18n.t('Optional. One or many of: serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCodeCom, msCTLSign, msSGC, msEFS, nsSGC.')"
      :disabled="!isResign && !isNew && !isClone"
    />
    <form-group-days namespace="days"
      :column-label="$i18n.t('Days')"
      :text="$i18n.t('Number of days the CA will be valid. (value greater than 825 wont work on some devices)')"
      :disabled="!isResign && !isNew && !isClone"
    />
    <form-group-ocsp-url namespace="ocsp_url"
      :column-label="$i18n.t('OCSP Url')"
      :text="$i18n.t('Optional. This is the url of the OCSP server that will be added in the certificate.')"
      :disabled="!isResign && !isNew && !isClone"
    />

    <form-group-cert v-if="!isResign"
      namespace="cert"
      :column-label="$i18n.t('Certificate')"
      :disabled="!isResign && !isNew && !isClone"
      auto-fit
    />
  </div>
</template>
<script>
import i18n from '@/utils/locale'
import { computed, toRefs } from '@vue/composition-api'
import {
  FormGroupIdentifier,
  FormGroupCn,
  FormGroupMail,
  FormGroupOrganisationalUnit,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  // FormGroupPostalCode,
  FormGroupKeyType,
  FormGroupKeySize,
  FormGroupDigest,
  FormGroupKeyUsage,
  FormGroupExtendedKeyUsage,
  FormGroupDays,
  FormGroupOcspUrl,
  FormGroupCert
} from './'

const components = {
  FormGroupIdentifier,
  FormGroupCn,
  FormGroupMail,
  FormGroupOrganisationalUnit,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  // FormGroupPostalCode,
  FormGroupKeyType,
  FormGroupKeySize,
  FormGroupDigest,
  FormGroupKeyUsage,
  FormGroupExtendedKeyUsage,
  FormGroupDays,
  FormGroupOcspUrl,
  FormGroupCert
}

export const props = {
  form: {
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
  },
  isResign: {
    type: Boolean,
    default: false
  }
}

import { keyTypes, keySizes } from '../../config'

export const setup = (props) => {

  const {
    form,
    isResign
  } = toRefs(props)

  const keySizeOptions = computed(() => {
    const { key_type } = form.value || {}
    if (key_type) {
      const { [+key_type]: { sizes = [] } = {} } = keyTypes
      return sizes.map(size => ({ text: `${size}`, value: `${size}` }))
    }
    return keySizes
  })

  const apiFeedback = computed(() => {
    return (isResign.value) ? i18n.t('Changing this value will invalidate the previously signed certificates using EAP-TLS.')
      : '';
  })

  return {
    keySizeOptions,
    apiFeedback,
  }
}

// @vue/component
export default {
  name: 'the-form-fields',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

