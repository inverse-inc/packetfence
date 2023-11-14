<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" active>
        <form-group-identifier v-if="!isNew && !isClone"
          namespace="id"
          :column-label="$i18n.t('Identifier')"
          :disabled="!isNew && !isClone"
        />
        <form-group-cn namespace="cn"
          :column-label="$i18n.t('Common Name')"
          :disabled="!isNew && !isClone"
        />
        <form-group-mail namespace="mail"
          :column-label="$i18n.t('Email')"
          :disabled="!isNew && !isClone"
        />
        <form-group-organisational-unit namespace="organisational_unit"
          :column-label="$i18n.t('Organisational Unit')"
          :disabled="!isNew && !isClone"
        />
        <form-group-organisation namespace="organisation"
          :column-label="$i18n.t('Organisation')"
          :disabled="!isNew && !isClone"
        />
        <form-group-country namespace="country"
          :column-label="$i18n.t('Country')"
          :disabled="!isNew && !isClone"
        />
        <form-group-state namespace="state"
          :column-label="$i18n.t('State or Province')"
          :disabled="!isNew && !isClone"
        />
        <form-group-locality namespace="locality"
          :column-label="$i18n.t('Locality')"
          :disabled="!isNew && !isClone"
        />
        <form-group-street-address namespace="street_address"
          :column-label="$i18n.t('Street Address')"
          :disabled="!isNew && !isClone"
        />
        <!-- temporarily hidden
        <form-group-postal-code namespace="postal_code"
          :column-label="$i18n.t('Postal Code')"
          :disabled="!isNew && !isClone"
        />
        -->
        <form-group-key-type namespace="key_type"
          :column-label="$i18n.t('Key type')"
          :disabled="!isNew && !isClone"
        />
        <form-group-key-size namespace="key_size"
          :column-label="$i18n.t('Key size')"
          :disabled="!isNew && !isClone"
          :options="keySizeOptions"
        />
        <form-group-digest namespace="digest"
          :column-label="$i18n.t('Digest')"
          :disabled="!isNew && !isClone"
        />
        <form-group-key-usage namespace="key_usage"
          :column-label="$i18n.t('Key usage')"
          :text="$i18n.t('Optional. One or many of: digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly, decipherOnly.')"
          :disabled="!isNew && !isClone"
        />
        <form-group-extended-key-usage namespace="extended_key_usage"
          :column-label="$i18n.t('Extended key usage')"
          :text="$i18n.t('Optional. One or many of: serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCodeCom, msCTLSign, msSGC, msEFS, nsSGC.')"
          :disabled="!isNew && !isClone"
        />
        <form-group-days namespace="days"
          :column-label="$i18n.t('Days')"
          :text="$i18n.t('Number of days the CA will be valid. (value greater than 825 wont work on some devices)')"
          :disabled="!isNew && !isClone"
        />
        <form-group-ocsp-url namespace="ocsp_url"
          :column-label="$i18n.t('OCSP Url')"
          :text="$i18n.t('Optional. This is the url of the OCSP server that will be added in the certificate.')"
          :disabled="!isNew && !isClone"
        />
        <form-group-cert namespace="cert"
          :column-label="$i18n.t('Certificate')"
          :disabled="!isNew && !isClone"
          auto-fit
        />
      </base-form-tab>

      <template #tabs-end v-if="!isNew && !isClone">
        <div class="text-right mr-3 mb-1">
          <button-ca-resign
            :id="id" :form="form" class="my-1 mr-1" @change="updateForm" />
          <button-ca-generate-csr
            :id="id" :form="form" class="my-1 mr-1" />
        </div>
      </template>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'
import { BaseForm, BaseFormTab } from '@/components/new/'
import schemaFn from '../schema'
import {
  ButtonCaResign,
  ButtonCaGenerateCsr,
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
  BaseForm,
  BaseFormTab,

  ButtonCaResign,
  ButtonCaGenerateCsr,
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

  const updateForm = item => {
    form.value = item
  }

  return {
    schema,
    keySizeOptions,
    updateForm
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

