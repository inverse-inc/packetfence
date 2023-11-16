<template>
  <div>
    <form-group-identifier v-if="disableInputsRegular"
      namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="!isNew && !isClone"
    />
    <form-group-cn namespace="cn"
      :column-label="$i18n.t('Common Name')"
      :disabled="disableInputsRegular"
    />
    <form-group-mail namespace="mail"
      :column-label="$i18n.t('Email')"
      :disabled="disableInputsRegular"
    />
    <form-group-organisational-unit namespace="organisational_unit"
      :column-label="$i18n.t('Organisational Unit')"
      :disabled="disableInputsRegular"
    />
    <form-group-organisation namespace="organisation"
      :column-label="$i18n.t('Organisation')"
      :disabled="disableInputsRegular"
      :api-feedback="apiFeedback"
    />
    <form-group-country namespace="country"
      :column-label="$i18n.t('Country')"
      :disabled="disableInputsRegular"
      :api-feedback="apiFeedback"
    />
    <form-group-state namespace="state"
      :column-label="$i18n.t('State or Province')"
      :disabled="disableInputsRegular"
      :api-feedback="apiFeedback"
    />
    <form-group-locality namespace="locality"
      :column-label="$i18n.t('Locality')"
      :disabled="disableInputsRegular"
      :api-feedback="apiFeedback"
    />
    <form-group-street-address namespace="street_address"
      :column-label="$i18n.t('Street Address')"
      :disabled="disableInputsRegular"
    />
    <!-- temporarily hidden
    <form-group-postal-code namespace="postal_code"
      :column-label="$i18n.t('Postal Code')"
      :disabled="disableInputsRegular"
    />
    -->
    <form-group-key-type namespace="key_type"
      :column-label="$i18n.t('Key type')"
      :disabled="disableInputsKeys"
    />
    <form-group-key-size namespace="key_size"
      :column-label="$i18n.t('Key size')"
      :disabled="disableInputsKeys"
      :options="keySizeOptions"
    />
    <form-group-digest namespace="digest"
      :column-label="$i18n.t('Digest')"
      :disabled="disableInputsRegular"
    />
    <form-group-key-usage namespace="key_usage"
      :column-label="$i18n.t('Key usage')"
      :text="$i18n.t('Optional. One or many of: digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly, decipherOnly.')"
      :disabled="disableInputsRegular"
    />
    <form-group-extended-key-usage namespace="extended_key_usage"
      :column-label="$i18n.t('Extended key usage')"
      :text="$i18n.t('Optional. One or many of: serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCodeCom, msCTLSign, msSGC, msEFS, nsSGC.')"
      :disabled="disableInputsRegular"
    />
    <form-group-days namespace="days"
      :column-label="$i18n.t('Days')"
      :text="$i18n.t('Number of days the CA will be valid. (value greater than 825 wont work on some devices)')"
      :disabled="disableInputsRegular"
    />
    <form-group-ocsp-url namespace="ocsp_url"
      :column-label="$i18n.t('OCSP Url')"
      :text="$i18n.t('Optional. This is the url of the OCSP server that will be added in the certificate.')"
      :disabled="disableInputsRegular"
    />
    <form-group-cert v-if="!isResign && !isCsr"
      namespace="cert"
      :column-label="$i18n.t('Certificate')"
      :disabled="disableInputsSpecial"
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
  },
  isCsr: {
    type: Boolean,
    default: false
  }
}

import { keyTypes, keySizes } from '../../config'

export const setup = (props) => {

  const {
    form,
    isNew,
    isClone,
    isResign,
    isCsr
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
    return (isResign.value || isCsr.value)
      ? i18n.t('Changing this value will invalidate the previously signed certificates using EAP-TLS.')
      : '';
  })

  const disableInputsRegular = computed(() => !isResign.value && !isCsr.value && !isNew.value && !isClone.value)
  const disableInputsSpecial = computed(() => !isResign.value && !isCsr.value)
  const disableInputsKeys = computed(() => isResign.value || isCsr.value || (!isNew.value && !isClone.value))

  return {
    keySizeOptions,
    apiFeedback,

    disableInputsRegular,
    disableInputsSpecial,
    disableInputsKeys
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

