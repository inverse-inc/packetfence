<template>
  <div class="w-100">
    <b-row align-v="center" no-gutters>
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
      <b-col cols="3" class="base-flex-wrap pr-1">
        <base-input
          :namespace="`${namespace}.cidr`"
          :placeholder="$t('IP address / prefix (e.g. 10.10.100.1/24)')"
        />
      </b-col>
      <b-col cols="1" class="base-flex-wrap">
        <base-input-toggle
          :namespace="`${namespace}.dhcp`"
          :options="dhcpOptions"
          :title="$t('Serve DHCP on this VLAN: the connector relays the requests to the PacketFence DHCP server, which serves the scope below')"
          label-right
        />
      </b-col>
      <b-col cols="1" class="base-flex-wrap">
        <base-input-toggle
          :namespace="`${namespace}.dns_server`"
          :options="dnsOptions"
          :title="$t('Captive DNS on this VLAN: the connector answers every DNS query with the interface address')"
          label-right
        />
      </b-col>
    </b-row>
    <b-collapse :visible="dhcpEnabled">
      <b-row v-if="dhcpEnabled" align-v="center" no-gutters class="mt-1 pl-3 border-left">
        <b-col cols="3" class="base-flex-wrap pr-1">
          <base-input
            :namespace="`${namespace}.dhcp_start`"
            :placeholder="$t('Range start (e.g. 10.10.100.10)')"
          />
        </b-col>
        <b-col cols="3" class="base-flex-wrap pr-1">
          <base-input
            :namespace="`${namespace}.dhcp_end`"
            :placeholder="$t('Range end (e.g. 10.10.100.250)')"
          />
        </b-col>
        <b-col cols="3" class="base-flex-wrap pr-1">
          <base-input-number
            :namespace="`${namespace}.dhcp_default_lease_time`"
            :placeholder="$t('Default lease (s)')"
            :min="1"
          />
        </b-col>
        <b-col cols="3" class="base-flex-wrap">
          <base-input-number
            :namespace="`${namespace}.dhcp_max_lease_time`"
            :placeholder="$t('Max lease (s)')"
            :min="1"
          />
        </b-col>
      </b-row>
      <b-row v-if="dhcpEnabled" align-v="center" no-gutters class="mt-1 pl-3 border-left">
        <b-col cols="4" class="base-flex-wrap pr-1">
          <base-input
            :namespace="`${namespace}.dns`"
            :placeholder="$t('DNS servers (comma separated, defaults to this interface when DNS is enabled)')"
          />
        </b-col>
        <b-col cols="4" class="base-flex-wrap pr-1">
          <base-input
            :namespace="`${namespace}.gateway`"
            :placeholder="$t('Gateway (defaults to the interface address)')"
          />
        </b-col>
        <b-col cols="4" class="base-flex-wrap">
          <base-input
            :namespace="`${namespace}.domain_name`"
            :placeholder="$t('Domain name (optional)')"
          />
        </b-col>
      </b-row>
    </b-collapse>
  </div>
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

import { computed, unref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {
  const metaProps = useInputMeta(props, context)
  const { value: inputValue } = useInputValue(metaProps, context)

  const dhcpEnabled = computed(() => {
    const { dhcp } = unref(inputValue) || {}
    return dhcp === 'enabled'
  })

  const dhcpOptions = [
    { value: 'disabled', label: i18n.t('DHCP') },
    { value: 'enabled', label: i18n.t('DHCP'), color: 'var(--primary)' }
  ]
  const dnsOptions = [
    { value: 'disabled', label: i18n.t('DNS') },
    { value: 'enabled', label: i18n.t('DNS'), color: 'var(--primary)' }
  ]

  return {
    dhcpEnabled,
    dhcpOptions,
    dnsOptions
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
