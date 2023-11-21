<template>
  <div>
    <form-group-identifier v-if="!isResign"
      namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="!isNew && !isClone"
    />
    <form-group-profile-identifier v-if="!isResign"
      namespace="profile_id"
      :column-label="$i18n.t('Certificate Template')"
      :text="$i18n.t('Certificate template used for this certificate.')"
      :disabled="!isNew && !isClone"
    />
    <form-group-cn namespace="cn"
      :column-label="$i18n.t('Common Name')"
      :disabled="disabled"
    />
    <form-group-mail namespace="mail"
      :column-label="$i18n.t('Email')"
      :disabled="disabled"
    />
    <form-group-dns-names namespace="dns_names"
      :column-label="$i18n.t('DNS Names')"
      :text="$i18n.t('List of domains separated by a comma.')"
      :disabled="disabled"
    />
    <form-group-ip-addresses namespace="ip_addresses"
      :column-label="$i18n.t('IP Addresses')"
      :text="$i18n.t('List of IP Addresses separated by a comma.')"
      :disabled="disabled"
    />
    <form-group-organisational-unit namespace="organisational_unit"
      :column-label="$i18n.t('Organisational Unit')"
      :disabled="disabled"
    />
    <form-group-organisation namespace="organisation"
      :column-label="$i18n.t('Organisation')"
      :api-feedback="apiFeedback"
      :disabled="disabled"
    />
    <form-group-country namespace="country"
      :column-label="$i18n.t('Country')"
      :api-feedback="apiFeedback"
      :disabled="disabled"
    />
    <form-group-state namespace="state"
      :column-label="$i18n.t('State or Province')"
      :api-feedback="apiFeedback"
      :disabled="disabled"
    />
    <form-group-locality namespace="locality"
      :column-label="$i18n.t('Locality')"
      :api-feedback="apiFeedback"
      :disabled="disabled"
    />
    <form-group-street-address namespace="street_address"
      :column-label="$i18n.t('Street Address')"
      :disabled="disabled"
    />
    <!-- temporarily hidden
    <form-group-postal-code namespace="postal_code"
      :column-label="$i18n.t('Postal Code')"
      :disabled="disabled"
    />
    -->
  </div>
</template>
<script>
import i18n from '@/utils/locale'
import { computed, toRefs } from '@vue/composition-api'
import {
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
  // FormGroupPostalCode,
} from './'

const components = {
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
  // FormGroupPostalCode,

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

export const setup = (props) => {

  const {
    isNew,
    isClone,
    isResign
  } = toRefs(props)

  const apiFeedback = computed(() => {
    return (isResign.value)
      ? i18n.t('Changing this value will invalidate the previously signed certificates using EAP-TLS.')
      : '';
  })

  const disabled = computed(() => !isResign.value && !isNew.value && !isClone.value)

  return {
    apiFeedback,
    disabled,
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