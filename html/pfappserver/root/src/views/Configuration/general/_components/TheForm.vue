<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-domain namespace="domain"
      :column-label="$i18n.t('Domain')"
      :text="$i18n.t('Domain name of PacketFence system. Changing this requires to restart haproxy-portal.')"
    />

    <form-group-hostname namespace="hostname"
      :column-label="$i18n.t('Hostname')"
      :text="$i18n.t('Hostname of PacketFence system. This is concatenated with the domain in Apache rewriting rules and therefore must be resolvable by clients. Changing this requires to restart haproxy-portal.')"
    />

    <form-group-dhcp-servers namespace="dhcpservers"
      :column-label="$i18n.t('DHCP servers')"
      :text="$i18n.t('Comma-separated list of DHCP servers.')"
    />

    <form-group-timezone namespace="timezone"
      :column-label="$i18n.t('Timezone')"
      :text="$i18n.t(`System's timezone in string format. List generated from Perl library DateTime::TimeZone. When left empty, it will use the timezone of the server. You will need to reboot the server after changing this setting.`)"
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
  FormGroupDhcpServers,
  FormGroupDomain,
  FormGroupHostname,
  FormGroupTimezone
} from './'

const components = {
  BaseForm,

  FormGroupDhcpServers,
  FormGroupDomain,
  FormGroupHostname,
  FormGroupTimezone
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

