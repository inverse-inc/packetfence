<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-accounting namespace="accounting"
      :column-label="$i18n.t('Accounting')"
      :text="$i18n.t('Should we handle accouting data for inline clients? This controls inline accouting tasks in pfcron.')"
    />

    <form-group-layer3-accounting-session-timeout namespace="layer3_accounting_session_timeout"
      :column-label="$i18n.t('Accounting session timeout')"
      :text="$i18n.t(`Accounting sessions created by pfbandwidthd that haven't been updated for more than this amount of seconds will be considered inactive. This should be higher than the interval at which pfcron runs Defaults to 300 - 5 minutes.`)"
    />

    <form-group-layer3-accounting-sync-interval namespace="layer3_accounting_sync_interval"
      :column-label="$i18n.t('Accounting sync interval')"
      :text="$i18n.t('Interval at which pfbandwidthd should dump collected information into the database. This should be lower than the interval at which pfcron runs. Defaults to 41 seconds.')"
    />

    <form-group-ports-redirect namespace="ports_redirect"
      :column-label="$i18n.t('Ports redirect')"
      :text="$i18n.t(`Ports to intercept and redirect for trapped and unregistered systems. Defaults to 80/tcp (HTTP), 443/tcp (HTTPS). Redirecting 443/tcp (SSL) will work, although users might get certificate errors if you didn't install a valid certificate or if you don't use DNS (although IP-based certificates supposedly exist). Redirecting 53/udp (DNS) seems to have issues and is also not recommended.`)"
    />

    <form-group-should-reauth-on-vlan-change namespace="should_reauth_on_vlan_change"
      :column-label="$i18n.t('Reauthenticate node')"
      :text="$i18n.t('Should have to reauthenticate the node if vlan change.')"
    />

    <form-group-interface-snat namespace="interfaceSNAT"
      :column-label="$i18n.t('SNAT Interface')"
      :text="$i18n.t('Comma-separated list of interfaces used to SNAT inline level 2 traffic.')"
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
  FormGroupAccounting,
  FormGroupLayer3AccountingSessionTimeout,
  FormGroupLayer3AccountingSyncInterval,
  FormGroupPortsRedirect,
  FormGroupShouldReauthOnVlanChange,
  FormGroupInterfaceSnat
} from './'

const components = {
  BaseForm,

  FormGroupAccounting,
  FormGroupLayer3AccountingSessionTimeout,
  FormGroupLayer3AccountingSyncInterval,
  FormGroupPortsRedirect,
  FormGroupShouldReauthOnVlanChange,
  FormGroupInterfaceSnat
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
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

