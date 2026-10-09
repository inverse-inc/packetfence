<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Identifier')"
      :disabled="!isNew && !isClone"
    />

    <form-group-default-eap-type namespace="default_eap_type"
      :column-label="$i18n.t('Default EAP Type')"
    />

    <form-group-timer-expire namespace="timer_expire"
      :column-label="$i18n.t('Expires')"
      :text="$i18n.t('The timeout in seconds to keep correlation between EAP-Response packets with EAP-Request packets.')"
    />

    <form-group-ignore-unknown-eap-types namespace="ignore_unknown_eap_types"
      :column-label="$i18n.t('Ignore Unknown EAP Types')"
    />

    <form-group-cisco-accounting-username-bug namespace="cisco_accounting_username_bug"
      :column-label="$i18n.t('Cisco Accounting Username Bug')"
    />

    <form-group-max-sessions namespace="max_sessions"
      :column-label="$i18n.t('Max Sessions')"
    />

    <form-group-eap-authentication-types namespace="eap_authentication_types"
      :column-label="$i18n.t('EAP Authentication Types')"
    />

    <form-group-tls-tlsprofile namespace="tls_tlsprofile"
      :column-label="$i18n.t('TLS Profile')"
    />

    <form-group-ttls-tlsprofile namespace="ttls_tlsprofile"
      :column-label="$i18n.t('TTLS Profile')"
    />

    <form-group-peap-tlsprofile namespace="peap_tlsprofile"
      :column-label="$i18n.t('PEAP Profile')"
    />

    <form-group-fast-config namespace="fast_config"
                            :column-label="$i18n.t('Fast Profile')"
    />
    <form-group-teap-config namespace="teap_config"
                            :column-label="$i18n.t('TEAP Profile')"
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
  FormGroupDefaultEapType,
  FormGroupTimerExpire,
  FormGroupIgnoreUnknownEapTypes,
  FormGroupCiscoAccountingUsernameBug,
  FormGroupMaxSessions,
  FormGroupEapAuthenticationTypes,
  FormGroupTlsTlsprofile,
  FormGroupTtlsTlsprofile,
  FormGroupPeapTlsprofile,
  FormGroupFastConfig,
  FormGroupTeapConfig
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupDefaultEapType,
  FormGroupTimerExpire,
  FormGroupIgnoreUnknownEapTypes,
  FormGroupCiscoAccountingUsernameBug,
  FormGroupMaxSessions,
  FormGroupEapAuthenticationTypes,
  FormGroupTlsTlsprofile,
  FormGroupTtlsTlsprofile,
  FormGroupPeapTlsprofile,
  FormGroupFastConfig,
  FormGroupTeapConfig
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
