<template>
  <b-row class="w-100" align-v="center" no-gutters>
    <b-col cols="4" class="base-flex-wrap pr-1">
      <base-input
        :namespace="`${namespace}.parent`"
        :placeholder="$t('Parent interface (e.g. eth0)')"
      />
    </b-col>
    <b-col cols="3" class="base-flex-wrap pr-1">
      <base-input-number
        :namespace="`${namespace}.vlan`"
        :placeholder="$t('VLAN ID')"
        :min="1"
        :max="4094"
      />
    </b-col>
    <b-col cols="4" class="base-flex-wrap pr-1">
      <base-input
        :namespace="`${namespace}.cidr`"
        :placeholder="$t('IP address / prefix (e.g. 10.10.100.1/24)')"
      />
    </b-col>
    <b-col cols="1" class="base-flex-wrap">
      <base-input-toggle
        :namespace="`${namespace}.dhcp_relay`"
        :options="dhcpRelayOptions"
        :title="$t('Relay DHCP on this interface to the PacketFence DHCP server')"
        label-right
      />
    </b-col>
  </b-row>
</template>
<script>
import {
  BaseInput,
  BaseInputNumber,
  BaseInputToggle
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputNumber,
  BaseInputToggle
}

import i18n from '@/utils/locale'
import { useInputMetaProps } from '@/composables/useMeta'
import { useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = () => {
  const dhcpRelayOptions = [
    { value: 'disabled', label: i18n.t('DHCP') },
    { value: 'enabled', label: i18n.t('DHCP'), color: 'var(--primary)' }
  ]
  return {
    dhcpRelayOptions
  }
}

// @vue/component
export default {
  name: 'base-interface',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
