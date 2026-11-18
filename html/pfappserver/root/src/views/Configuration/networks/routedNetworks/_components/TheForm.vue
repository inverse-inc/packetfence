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
      </base-form-tab>
      <base-form-tab :title="$i18n.t('DHCP')"
                     v-if="isType('vlan-isolation', 'vlan-registration', 'dns-enforcement')">
        <form-group-dhcpd namespace="dhcpd"
                          :column-label="$i18n.t('DHCP Server')"
                          enabled-value="enabled"
                          disabled-value="disabled"
        />

        <form-group-algorithm namespace="algorithm"
                              :column-label="$i18n.t('Algorithm')"
        />

        <form-group-pool-backend namespace="pool_backend"
                                 :column-label="$i18n.t('DHCP Pool Backend Type')"
        />

        <form-group-dhcp-reply-ip namespace="dhcp_reply_ip"
                                 :column-label="$i18n.t('IP Address to reply to')"
        />

        <form-group-dhcp-start namespace="dhcp_start"
                               :column-label="$i18n.t('Starting IP Address')"
        />

        <form-group-dhcp-end namespace="dhcp_end"
                             :column-label="$i18n.t('Ending IP Address')"
        />

        <form-group-dhcp-default-lease-time namespace="dhcp_default_lease_time"
                                            :column-label="$i18n.t('Default Lease Time')"
        />

        <form-group-dhcp-max-lease-time namespace="dhcp_max_lease_time"
                                        :column-label="$i18n.t('Max Lease Time')"
        />

        <form-group-ip-reserved namespace="ip_reserved"
                                :column-label="$i18n.t('IP Addresses reserved')"
                                :text="$i18n.t('Range like 192.168.0.1-192.168.0.20 and or IP like 192.168.0.22,192.168.0.24 will be excluded from the DHCP pool.')"
        />

        <form-group-ip-assigned namespace="ip_assigned"
                                :column-label="$i18n.t('IP Addresses assigned')"
                                :text="$i18n.t('List like 00:11:22:33:44:55:192.168.0.12,11:22:33:44:55:66:192.168.0.13.')"
        />

        <form-group-dns namespace="dns"
                        :column-label="$i18n.t('DNS Server')"
                        :text="$i18n.t('Should match the IP of a registration interface or the production DNS server(s) (comma delimited list of IP addresses).')"
        />

        <form-group-portal-fqdn namespace="portal_fqdn"
                                :column-label="$i18n.t('Portal FQDN')"
                                :text="$i18n.t('Define the FQDN of the portal for this network. Leaving empty will use the FQDN of the PacketFence server.')"
        />

        <form-group-gateway namespace="gateway"
                            :column-label="$i18n.t('Client Gateway')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Routing')"
                     v-if="isType('vlan-isolation', 'vlan-registration', 'dns-enforcement')">
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
  FormGroupDescription,
  FormGroupDhcpd,
  FormGroupDhcpDefaultLeaseTime,
  FormGroupDhcpEnd,
  FormGroupDhcpMaxLeaseTime,
  FormGroupDhcpReplyIp,
  FormGroupDhcpStart,
  FormGroupDns,
  FormGroupGateway,
  FormGroupIdentifier,
  FormGroupIpAssigned,
  FormGroupIpReserved,
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
  FormGroupDescription,
  FormGroupDhcpd,
  FormGroupDhcpDefaultLeaseTime,
  FormGroupDhcpEnd,
  FormGroupDhcpMaxLeaseTime,
  FormGroupDhcpReplyIp,
  FormGroupDhcpStart,
  FormGroupDns,
  FormGroupGateway,
  FormGroupIdentifier,
  FormGroupIpAssigned,
  FormGroupIpReserved,
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

  const isType = (...types) => {
    const {type} = form.value || {}
    return types.includes(type)
  }

  watch(
    () => form.value && form.value.type, // when `form.type` is mutated
    () => {
      const {type} = form.value || {}
      if (type === 'other') // and `type` is 'other'
        form.value.dhcpd = 'disabled' // disable `dhcpd`
    }
  )

  return {
    schema,
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

