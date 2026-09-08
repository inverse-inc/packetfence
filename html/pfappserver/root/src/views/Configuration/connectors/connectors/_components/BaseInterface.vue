<template>
  <div class="w-100">
    <!-- align-v="start": when one input shows its error text below, the other
         inputs of the row must not be re-centered against the taller column. -->
    <b-row align-v="start" no-gutters>
      <b-col cols="3" class="base-flex-wrap pr-1">
        <base-input-chosen-one
          :namespace="`${namespace}.parent`"
          :placeholder="$t('Interface (e.g. eth0)')"
          :options="parentOptions"
          :taggable="true"
          :tag-placeholder="$t('Use this interface name')"
        />
        <small v-if="mainInterfaceLocked" class="d-block text-danger">
          {{ $t('{name} is the main interface of the connector host and cannot be reconfigured: set a VLAN ID to create a VLAN on it, or choose another interface.', { name: mainInterfaceLocked }) }}
        </small>
      </b-col>
      <b-col cols="2" class="base-flex-wrap pr-1">
        <base-input-number
          :namespace="`${namespace}.vlan`"
          :placeholder="$t('VLAN ID (none)')"
          :title="$t('802.1Q VLAN ID of the VLAN interface to create on top of the interface. Leave empty to assign the address to the interface itself.')"
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
      <b-col cols="4" class="base-interface-toggles d-flex align-items-center flex-wrap pl-2">
        <base-input-toggle class="mr-4"
          :namespace="`${namespace}.dhcp`"
          :options="dhcpOptions"
          :title="$t('Serve DHCP on this interface: the connector relays the requests to the PacketFence DHCP server, which serves the scope below')"
          label-right
        />
        <base-input-toggle
          :namespace="`${namespace}.dns_server`"
          :options="dnsOptions"
          :title="$t('Captive DNS on this interface: the connector answers every DNS query with the interface address')"
          label-right
        />
      </b-col>
    </b-row>
    <b-collapse :visible="dhcpEnabled">
      <div v-if="dhcpEnabled" class="mt-2 pl-3 border-left">
        <small class="text-muted d-block mb-1">{{ $t('DHCP scope served on this interface (the network is the one of the interface address)') }}</small>
        <b-row align-v="start" no-gutters>
          <b-col cols="3" class="pr-2">
            <label class="base-interface-field-label">{{ $t('Range start') }}</label>
            <base-input
              :namespace="`${namespace}.dhcp_start`"
              :placeholder="$t('e.g. 10.10.100.10')"
            />
          </b-col>
          <b-col cols="3" class="pr-2">
            <label class="base-interface-field-label">{{ $t('Range end') }}</label>
            <base-input
              :namespace="`${namespace}.dhcp_end`"
              :placeholder="$t('e.g. 10.10.100.250')"
            />
          </b-col>
          <b-col cols="3" class="pr-2">
            <label class="base-interface-field-label">{{ $t('Default lease (seconds)') }}</label>
            <base-input-number
              :namespace="`${namespace}.dhcp_default_lease_time`"
              placeholder="300"
              :min="1"
            />
          </b-col>
          <b-col cols="3">
            <label class="base-interface-field-label">{{ $t('Maximum lease (seconds)') }}</label>
            <base-input-number
              :namespace="`${namespace}.dhcp_max_lease_time`"
              placeholder="600"
              :min="1"
            />
          </b-col>
        </b-row>
        <b-row align-v="start" no-gutters class="mt-2">
          <b-col cols="4" class="pr-2">
            <label class="base-interface-field-label">{{ $t('DNS servers') }}</label>
            <base-input
              :namespace="`${namespace}.dns`"
              :placeholder="$t('Comma separated, defaults to this interface when DNS is enabled')"
            />
          </b-col>
          <b-col cols="4" class="pr-2">
            <label class="base-interface-field-label">{{ $t('Gateway') }}</label>
            <base-input
              :namespace="`${namespace}.gateway`"
              :placeholder="$t('Defaults to the interface address')"
            />
          </b-col>
          <b-col cols="4">
            <label class="base-interface-field-label">{{ $t('Domain name') }}</label>
            <base-input
              :namespace="`${namespace}.domain_name`"
              :placeholder="$t('Optional')"
            />
          </b-col>
        </b-row>
      </div>
    </b-collapse>
  </div>
</template>
<script>
import {
  BaseInput,
  BaseInputChosenOne,
  BaseInputNumber,
  BaseInputToggle
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputChosenOne,
  BaseInputNumber,
  BaseInputToggle
}

import { computed, inject, ref, unref, watch } from '@vue/composition-api'
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

  // Interface candidates: the interfaces reported by the connector host that
  // are not themselves VLAN sub-interfaces ("<name>.<vlan>"), the main one
  // (the interface holding the host's default route, through which the tunnel
  // runs) first. Any name can still be typed in (taggable), e.g. while the
  // connector is disconnected.
  const hostInterfaces = inject('connectorHostInterfaces', ref([]))
  const parentCandidates = computed(() => (hostInterfaces.value || [])
    .filter(({ name }) => name && !name.includes('.'))
  )
  // Without a VLAN ID the row reconfigures the interface itself, which is
  // refused for the main interface (by the connector too): hide it then.
  const hasVlan = computed(() => {
    const { vlan } = unref(inputValue) || {}
    return !['', null, undefined, 0, '0'].includes(vlan)
  })
  const parentOptions = computed(() => parentCandidates.value
    .filter(({ main }) => hasVlan.value || !main)
    .map(({ name, main }) => ({ text: main ? `${name} (${i18n.t('main')})` : name, value: name }))
  )
  // Name of the main interface when the row would reconfigure it (no VLAN
  // ID), so the row can say why the connector will refuse it.
  const mainInterfaceLocked = computed(() => {
    const { parent } = unref(inputValue) || {}
    const main = parentCandidates.value.find(({ main }) => main)
    return (!hasVlan.value && main && parent === main.name) ? main.name : null
  })

  // A new row gets the main interface as parent (a VLAN on it is the common
  // case); the user can still change it.
  const presetParent = () => {
    const { parent } = unref(inputValue) || {}
    const main = parentCandidates.value.find(({ main }) => main)
    if (!parent && main)
      inputValue.value = { ...(unref(inputValue) || {}), parent: main.name }
  }
  watch(parentCandidates, presetParent, { immediate: true })

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
    dnsOptions,
    mainInterfaceLocked,
    parentOptions
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
<style lang="scss">
// Match the height of a .base-flex-wrap input (form-control height plus the
// 0.25rem vertical margins) so the toggles sit centered on the inputs' line.
.base-interface-toggles {
  min-height: calc(1.5em + 0.75rem + 2px + 0.5rem);
}
// Field labels above the DHCP scope inputs.
.base-interface-field-label {
  display: block;
  margin-bottom: 0.125rem;
  font-size: $font-size-sm;
  color: $text-muted;
}
</style>
