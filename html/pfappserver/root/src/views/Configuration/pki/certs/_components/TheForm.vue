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
          namespace="id"
          :column-label="$i18n.t('Identifier')"
        />
        <form-group-profile-identifier namespace="profile_id"
          :column-label="$i18n.t('Certificate Template')"
          :text="$i18n.t('Certificate template used for this certificate.')"
        />
        <form-group-cn namespace="cn"
          :column-label="$i18n.t('Common Name')"
          :text="$i18n.t('Username for this certificate.')"
        />
        <form-group-mail namespace="mail"
          :column-label="$i18n.t('Email')"
          :text="$i18n.t('Email address of the user. The email with the certificate will be sent to this address.')"
        />
        <form-group-dns-names namespace="dns_names"
          :column-label="$i18n.t('DNS Names')"
          :text="$i18n.t('List of domains separated by a comma.')"
        />
        <form-group-ip-addresses namespace="ip_addresses"
          :column-label="$i18n.t('IP Addresses')"
          :text="$i18n.t('List of IP Addresses separated by a comma.')"
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
      </base-form-tab>

      <template #tabs-end v-if="!isNew && !isClone">
        <div class="text-right mr-3 mb-1">
          <button-certificate-copy
            :disabled="!isServiceAlive" :id="id" class="my-1 mr-1" />
          <button-certificate-download v-if="!form.scep || !form.csr"
            :disabled="!isServiceAlive" :id="id" class="my-1 mr-1" />
          <button-certificate-email v-if="!form.scep || !form.csr"
            :disabled="!isServiceAlive" :id="id" class="my-1 mr-1" />
          <button-certificate-revoke
            :disabled="!isServiceAlive" :id="id" class="my-1 mr-1" />
        </div>
      </template>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import { BaseForm, BaseFormTab } from '@/components/new/'
import schemaFn from '../schema'
import {
  ButtonCertificateCopy,
  ButtonCertificateDownload,
  ButtonCertificateEmail,
  ButtonCertificateRevoke,
  FormGroupIdentifier,
  FormGroupProfileIdentifier,
  FormGroupCn,
  FormGroupMail,
  FormGroupDnsNames,
  FormGroupIpAddresses,
  FormGroupOrganisationalUnit,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  // FormGroupPostalCode
} from './'

const components = {
  BaseForm,
  BaseFormTab,
  ButtonCertificateCopy,
  ButtonCertificateDownload,
  ButtonCertificateEmail,
  ButtonCertificateRevoke,
  FormGroupIdentifier,
  FormGroupProfileIdentifier,
  FormGroupCn,
  FormGroupMail,
  FormGroupDnsNames,
  FormGroupIpAddresses,
  FormGroupOrganisationalUnit,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  // FormGroupPostalCode
}

export const props = {
  id: {
    type: String
  },
  profile_id: {
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

export const setup = (props, context) => {

  const schema = computed(() => schemaFn(props))

  const { root: { $store } = {} } = context

  const isServiceAlive = computed(() => {
    if ($store.getters['system/isSaas']) {
      const { pfpki: { available = false } = {} } = $store.getters['k8s/services']
      return available
    }
    else if ($store.getters['cluster/servicesByServer']) {
      const { pfpki: { hasAlive = false } = {} } = $store.getters['cluster/servicesByServer']
      return hasAlive
    }
    return false
  })

  return {
    schema,
    isServiceAlive
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

