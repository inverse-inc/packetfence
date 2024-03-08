<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" active>
        <form-group-identifier namespace="id"
                               :column-label="(isType('other')) ? $i18n.t('IP Address') : $i18n.t('Routed Network')"
                               :disabled="!isNew && !isClone"
        />

        <form-group-netmask namespace="netmask"
                            :column-label="$i18n.t('Netmask')"
        />

        <form-group-description namespace="description"
                                :column-label="$i18n.t('Description')"
        />

        <form-group-type namespace="type"
                         :column-label="$i18n.t('Type')"
        />

        <form-group-nat-enabled v-show="isType('inlinel3')"
                                namespace="nat_enabled"
                                :column-label="$i18n.t('Enable NAT')"
                                :enabled-value="1"
                                :disabled-value="0"
        />

        <form-group-nat-dns v-show="isType('inlinel3')"
                            namespace="nat_dns"
                            :column-label="$i18n.t('Enable DNS NAT')"
                            :enabled-value="1"
                            :disabled-value="0"
        />

        <form-group-fake-mac-enabled v-show="isType('inlinel3')"
                                     namespace="fake_mac_enabled"
                                     :column-label="$i18n.t('Fake MAC Address')"
                                     :enabled-value="1"
                                     :disabled-value="0"
        />

        <form-group-coa v-show="isType('inlinel3')"
                        namespace="coa"
                        :column-label="$i18n.t('Enable CoA')"
                        :text="$i18n.t('Enabling this will send a CoA request to the equipment to reevaluate network access of endpoints.')"
                        enabled-value="enabled"
                        disabled-value="disabled"
        />

        <form-group-netflow-accounting-enabled v-show="isType('inlinel3')"
                                               namespace="netflow_accounting_enabled"
                                               :column-label="$i18n.t('Netflow Accounting Enabled')"
                                               :text="$i18n.t('Enable Netflow on this network to enable accounting.')"
                                               enabled-value="enabled"
                                               disabled-value="disabled"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('DHCP')"
                     v-if="isType('vlan-isolation', 'vlan-registration', 'dns-enforcement', 'inlinel3')">
        <b-form-group v-show="isFakeMacEnabled"
                      label-cols="3">
          <div class="alert alert-warning mb-0">
            <strong>{{ $i18n.t('Note:') }}</strong>
            {{ $i18n.t('DHCP Server is disabled when Fake MAC Address is enabled.') }}
          </div>
        </b-form-group>

        <form-group-dhcpd namespace="dhcpd"
                          :column-label="$i18n.t('DHCP Server')"
                          :disabled="isFakeMacEnabled"
                          enabled-value="enabled"
                          disabled-value="disabled"
        />

        <form-group-algorithm namespace="algorithm"
                              :column-label="$i18n.t('Algorithm')"
                              :disabled="isFakeMacEnabled"
        />

        <form-group-pool-backend namespace="pool_backend"
                                 :column-label="$i18n.t('DHCP Pool Backend Type')"
                                 :disabled="isFakeMacEnabled"
        />

        <form-group-dhcp-reply-ip namespace="dhcp_reply_ip"
                                 :column-label="$i18n.t('IP Address to reply to')"
                                 :disabled="isFakeMacEnabled"
        />

        <form-group-dhcp-start namespace="dhcp_start"
                               :column-label="$i18n.t('Starting IP Address')"
                               :disabled="isFakeMacEnabled"
        />

        <form-group-dhcp-end namespace="dhcp_end"
                             :column-label="$i18n.t('Ending IP Address')"
                             :disabled="isFakeMacEnabled"
        />

        <form-group-dhcp-default-lease-time namespace="dhcp_default_lease_time"
                                            :column-label="$i18n.t('Default Lease Time')"
                                            :disabled="isFakeMacEnabled"
        />

        <form-group-dhcp-max-lease-time namespace="dhcp_max_lease_time"
                                        :column-label="$i18n.t('Max Lease Time')"
                                        :disabled="isFakeMacEnabled"
        />

        <form-group-ip-reserved namespace="ip_reserved"
                                :column-label="$i18n.t('IP Addresses reserved')"
                                :text="$i18n.t('Range like 192.168.0.1-192.168.0.20 and or IP like 192.168.0.22,192.168.0.24 will be excluded from the DHCP pool.')"
                                :disabled="isFakeMacEnabled"
        />

        <form-group-ip-assigned namespace="ip_assigned"
                                :column-label="$i18n.t('IP Addresses assigned')"
                                :text="$i18n.t('List like 00:11:22:33:44:55:192.168.0.12,11:22:33:44:55:66:192.168.0.13.')"
                                :disabled="isFakeMacEnabled"
        />

        <form-group-dns namespace="dns"
                        :column-label="$i18n.t('DNS Server')"
                        :text="$i18n.t('Should match the IP of a registration interface or the production DNS server(s) if the network is Inline L2/L3 (comma delimited list of IP addresses).')"
                        :disabled="isFakeMacEnabled"
        />

        <form-group-portal-fqdn namespace="portal_fqdn"
                                :column-label="$i18n.t('Portal FQDN')"
                                :text="$i18n.t('Define the FQDN of the portal for this network. Leaving empty will use the FQDN of the PacketFence server.')"
                                :disabled="isFakeMacEnabled"
        />

        <form-group-gateway namespace="gateway"
                            :column-label="$i18n.t('Client Gateway')"
                            :disabled="isFakeMacEnabled"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Routing')"
                     v-if="isType('vlan-isolation', 'vlan-registration', 'dns-enforcement', 'inlinel3')">
        <form-group-next-hop namespace="next_hop"
                             :column-label="$i18n.t('Router IP')"
                             :text="$i18n.t('IP address of the router to reach this network.')"
        />
      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import {computed, toRefs, watch} from '@vue/composition-api'
import {BaseForm, BaseFormTab,} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAlgorithm,
  FormGroupCoa,
  FormGroupDescription,
  FormGroupDhcpd,
  FormGroupDhcpDefaultLeaseTime,
  FormGroupDhcpEnd,
  FormGroupDhcpMaxLeaseTime,
  FormGroupDhcpReplyIp,
  FormGroupDhcpStart,
  FormGroupDns,
  FormGroupFakeMacEnabled,
  FormGroupGateway,
  FormGroupIdentifier,
  FormGroupIpAssigned,
  FormGroupIpReserved,
  FormGroupNatDns,
  FormGroupNatEnabled,
  FormGroupNetflowAccountingEnabled,
  FormGroupNetmask,
  FormGroupNextHop,
  FormGroupPoolBackend,
  FormGroupPortalFqdn,
  FormGroupType
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupAlgorithm,
  FormGroupCoa,
  FormGroupDescription,
  FormGroupDhcpd,
  FormGroupDhcpDefaultLeaseTime,
  FormGroupDhcpEnd,
  FormGroupDhcpMaxLeaseTime,
  FormGroupDhcpReplyIp,
  FormGroupDhcpStart,
  FormGroupDns,
  FormGroupFakeMacEnabled,
  FormGroupGateway,
  FormGroupIdentifier,
  FormGroupIpAssigned,
  FormGroupIpReserved,
  FormGroupNatEnabled,
  FormGroupNatDns,
  FormGroupNetflowAccountingEnabled,
  FormGroupNetmask,
  FormGroupNextHop,
  FormGroupPoolBackend,
  FormGroupPortalFqdn,
  FormGroupType
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

  const {
    form
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const isFakeMacEnabled = computed(() => {
    const {fake_mac_enabled} = form.value || {}
    return fake_mac_enabled === 1
  })

  const isType = (...types) => {
    const {type} = form.value || {}
    return types.includes(type)
  }

  watch(
    () => form.value && form.value.type, // when `form.type` is mutated
    () => {
      const {type} = form.value || {}
      if (type !== 'inlinel3') // and `type` is not 'inlinel3'
        form.value.fake_mac_enabled = 0 // disable `fake_mac_enabled`
      if (type === 'other') // and `type` is 'other'
        form.value.dhcpd = 'disabled' // disable `dhcpd`
    }
  )

  return {
    schema,
    isFakeMacEnabled,
    isType
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

