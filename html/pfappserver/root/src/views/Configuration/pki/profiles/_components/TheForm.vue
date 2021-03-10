<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
    :isReadonly="!isNew && !isClone"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" active>
        <form-group-identifier v-if="!isNew && !isClone"
          namespace="ID"
          :column-label="$i18n.t('Identifier')"
        />
        <form-group-ca-id namespace="ca_id"
          :column-label="$i18n.t('Certificate Authority')"
        />
        <form-group-name namespace="name"
          :column-label="$i18n.t('Name')"
          :text="$i18n.t('Profile Name.')"
        />
        <form-group-validity namespace="validity"
          :column-label="$i18n.t('Validity')"
          :text="$i18n.t('Number of days the certificate will be valid.')"
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
  FormGroupValidity,
  FormGroupKeyType,
  FormGroupKeySize,
  FormGroupDigest,
  FormGroupKeyUsage,
  FormGroupExtendedKeyUsage,
  FormGroupP12MailPassword,
  FormGroupP12MailSubject,
  FormGroupP12MailFrom,
  FormGroupP12MailHeader,
  FormGroupP12MailFooter
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupCaId,
  FormGroupName,
  FormGroupValidity,
  FormGroupKeyType,
  FormGroupKeySize,
  FormGroupDigest,
  FormGroupKeyUsage,
  FormGroupExtendedKeyUsage,
  FormGroupP12MailPassword,
  FormGroupP12MailSubject,
  FormGroupP12MailFrom,
  FormGroupP12MailHeader,
  FormGroupP12MailFooter
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

