<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
    :isReadonly="!isNew && !isClone"
  >
    <form-group-identifier v-if="!isNew && !isClone"
      namespace="ID"
      :column-label="$i18n.t('Identifier')"
    />
    <form-group-cn namespace="cn"
      :column-label="$i18n.t('Common Name')"
    />
    <form-group-mail namespace="mail"
      :column-label="$i18n.t('Email')"
    />
    <form-group-organisational-unit namespace="organisational_unit"
      :column-label="$i18n.t('Organisational Unit')"
    />
    <form-group-organisation namespace="organisation"
      :column-label="$i18n.t('Organisation')"
    />
    <form-group-country namespace="country"
      :column-label="$i18n.t('Country')"
    />
    <form-group-state namespace="state"
      :column-label="$i18n.t('State or Province')"
    />
    <form-group-locality namespace="locality"
      :column-label="$i18n.t('Locality')"
    />
    <form-group-street-address namespace="street_address"
      :column-label="$i18n.t('Street Address')"
    />
    <form-group-postal-code namespace="postal_code"
      :column-label="$i18n.t('Postal Code')"
    />
    <form-group-key-type namespace="key_type"
      :column-label="$i18n.t('Key type')"
    />
    <form-group-key-size namespace="key_size"
      :column-label="$i18n.t('Key size')"
      :options="keySizeOptions"
    />
    <form-group-digest namespace="digest"
      :column-label="$i18n.t('Digest')"
    />
    <form-group-key-usage namespace="key_usage"
      :column-label="$i18n.t('Key usage')"
      :text="$i18n.t('Optional. One or many of: digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly, decipherOnly.')"
    />
    <form-group-extended-key-usage namespace="extended_key_usage"
      :column-label="$i18n.t('Extended key usage')"
      :text="$i18n.t('Optional. One or many of: serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCodeCom, msCTLSign, msSGC, msEFS, nsSGC.')"
    />
    <form-group-days namespace="days"
      :column-label="$i18n.t('Days')"
      :text="$i18n.t('Number of days the CA will be valid.')"
    />
    <form-group-ocsp-url namespace="ocsp_url"
      :column-label="$i18n.t('OCSP Url')"
      :text="$i18n.t('Optional. This is the url of the OCSP server that will be added in the certificate.')"
    />
    <form-group-cert namespace="cert"
      :column-label="$i18n.t('Certificate')"
      auto-fit
    />
  </base-form>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
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
  FormGroupPostalCode,
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
  BaseForm,

  FormGroupIdentifier,
  FormGroupCn,
  FormGroupMail,
  FormGroupOrganisationalUnit,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  FormGroupPostalCode,
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
  id: {
    type: String
  },
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
  }
}

import { keyTypes, keySizes } from '../../config'

export const setup = (props) => {

  const {
    form
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const keySizeOptions = computed(() => {
    const { key_type } = form.value || {}
    if (key_type) {
      const { [+key_type]: { sizes = [] } = {} } = keyTypes
      return sizes.map(size => ({ text: `${size}`, value: `${size}` }))
    }
    return keySizes
  })

  return {
    schema,
    keySizeOptions
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

