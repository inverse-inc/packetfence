<template>
  <base-form
    :form="form"
    :isLoading="isLoading"
    isReadonly
  >
    <form-group-identifier
      namespace="ID"
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
    <form-group-revoked namespace="revoked"
      :column-label="$i18n.t('Revoked')"
    />
    <form-group-reason namespace="crl_reason"
      :column-label="$i18n.t('Reason')"
      :options="reasonsOptions"
    />
  </base-form>
</template>
<script>
import {
  BaseForm
} from '@/components/new/'
import {
  FormGroupIdentifier,
  FormGroupProfileIdentifier,
  FormGroupCn,
  FormGroupMail,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  FormGroupPostalCode,
  FormGroupRevoked,
  FormGroupReason
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupProfileIdentifier,
  FormGroupCn,
  FormGroupMail,
  FormGroupOrganisation,
  FormGroupCountry,
  FormGroupState,
  FormGroupLocality,
  FormGroupStreetAddress,
  FormGroupPostalCode,
  FormGroupRevoked,
  FormGroupReason
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
  isLoading: {
    type: Boolean,
    default: false
  }
}

import { revokeReasons } from '../../config'

const setup = () => {
  return {
    reasonsOptions: revokeReasons
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

