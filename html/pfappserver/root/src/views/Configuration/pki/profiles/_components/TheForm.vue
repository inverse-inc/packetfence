<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" active>
        <form-group-identifier v-if="!isNew && !isClone"
          namespace="ID"
          :column-label="$i18n.t('Identifier')"
          :disabled="!isNew && !isClone"
        />
        <form-group-ca-id namespace="ca_id"
          :column-label="$i18n.t('Certificate Authority')"
          :disabled="!isNew && !isClone"
        />
        <form-group-name namespace="name"
          :column-label="$i18n.t('Name')"
          :text="$i18n.t('Profile Name.')"
          :disabled="!isNew && !isClone"
        />
        <form-group-mail namespace="mail"
          :column-label="$i18n.t('Email')"
          :text="$i18n.t('Email address of the user. The email with the certificate will be sent to this address.')"
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
        <!-- temporarily hidden
        <form-group-postal-code namespace="postal_code"
          :column-label="$i18n.t('Postal Code')"
        />
        -->
        <form-group-validity namespace="validity"
          :column-label="$i18n.t('Validity')"
          :text="$i18n.t('Number of days the certificate will be valid.')"
        />
        <form-group-key-type namespace="key_type"
          :column-label="$i18n.t('Key type')"
          :disabled="!isNew && !isClone"
        />
        <form-group-key-size namespace="key_size"
          :column-label="$i18n.t('Key size')"
          :options="keySizeOptions"
        />
        <form-group-digest namespace="digest"
          :column-label="$i18n.t('Digest')"
          :disabled="!isNew && !isClone"
        />
        <form-group-key-usage namespace="key_usage"
          :column-label="$i18n.t('Key usage')"
          :text="$i18n.t('Optional. One or many of: digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly, decipherOnly.')"
        />
        <form-group-extended-key-usage namespace="extended_key_usage"
          :column-label="$i18n.t('Extended key usage')"
          :text="$i18n.t('Optional. One or many of: serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCodeCom, msCTLSign, msSGC, msEFS, nsSGC.')"
        />
        <form-group-ocsp-url namespace="ocsp_url"
          :column-label="$i18n.t('OCSP URL')"
          :text="$i18n.t('Optional. This is the URL of the OCSP server that will be added in the certificate. If empty then the ca one will be used')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('PKCS 12')">
        <form-group-p12-mail-password namespace="p12_mail_password"
          :column-label="$i18n.t('P12 mail password')"
          :text="$i18n.t('Email the password of the pkcs12 file.')"
        />
        <form-group-p12-mail-subject namespace="p12_mail_subject"
          :column-label="$i18n.t('P12 mail subject')"
          :text="$i18n.t('Email subject.')"
        />
        <form-group-p12-mail-from namespace="p12_mail_from"
          :column-label="$i18n.t('P12 mail from')"
          :text="$i18n.t('Sender email address.')"
        />
        <form-group-p12-mail-header namespace="p12_mail_header"
          :column-label="$i18n.t('P12 mail header')"
          :text="$i18n.t('Email header.')"
          auto-fit
        />
        <form-group-p12-mail-footer namespace="p12_mail_footer"
          :column-label="$i18n.t('P12 mail footer')"
          :text="$i18n.t('Email footer.')"
          auto-fit
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('SCEP')">
        <form-group-scep-enabled namespace="scep_enabled"
          :column-label="$i18n.t('Enable SCEP')"
          :text="$i18n.t('Enable SCEP for this template.')"
        />
        <form-group-scep-challenge-password namespace="scep_challenge_password"
          :column-label="$i18n.t('SCEP challenge password')"
          :text="$i18n.t('SCEP challenge password.')"
        />
        <form-group-scep-days-before-renewal namespace="scep_days_before_renewal"
          :column-label="$i18n.t('SCEP days before renewal')"
          :text="$i18n.t('Number of days before SCEP authorize renewal')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Cloud')">
        <form-group-cloud-enabled namespace="cloud_enabled"
          :column-label="$i18n.t('Enable Cloud Integration')"
          :text="$i18n.t('Enable Cloud integration for this template.')"
        />
        <form-group-cloud-service namespace="cloud_service"
          :column-label="$i18n.t('Cloud Service')"
          :text="$i18n.t('Cloud Service to integrate.')"
        />
      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupCaId,
  FormGroupName,
  FormGroupMail,
  FormGroupOrganisationalUnit,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  // FormGroupPostalCode,
  FormGroupValidity,
  FormGroupKeyType,
  FormGroupKeySize,
  FormGroupDigest,
  FormGroupKeyUsage,
  FormGroupExtendedKeyUsage,
  FormGroupOcspUrl,
  FormGroupP12MailPassword,
  FormGroupP12MailSubject,
  FormGroupP12MailFrom,
  FormGroupP12MailHeader,
  FormGroupP12MailFooter,
  FormGroupScepEnabled,
  FormGroupScepChallengePassword,
  FormGroupScepDaysBeforeRenewal,
  FormGroupCloudEnabled,
  FormGroupCloudService
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupCaId,
  FormGroupName,
  FormGroupMail,
  FormGroupOrganisationalUnit,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  // FormGroupPostalCode,
  FormGroupValidity,
  FormGroupKeyType,
  FormGroupKeySize,
  FormGroupDigest,
  FormGroupKeyUsage,
  FormGroupExtendedKeyUsage,
  FormGroupOcspUrl,
  FormGroupP12MailPassword,
  FormGroupP12MailSubject,
  FormGroupP12MailFrom,
  FormGroupP12MailHeader,
  FormGroupP12MailFooter,
  FormGroupScepEnabled,
  FormGroupScepChallengePassword,
  FormGroupScepDaysBeforeRenewal,
  FormGroupCloudEnabled,
  FormGroupCloudService
}

export const props = {
  id: {
    type: String
  },
  ca_id: {
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

