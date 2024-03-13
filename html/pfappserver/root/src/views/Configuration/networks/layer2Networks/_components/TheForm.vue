<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
                           disabled
                           :column-label="$i18n.t('Layer2 Network')"
    />

    <form-group-description namespace="description"
                            :column-label="$i18n.t('Description')"
    />

    <form-group-algorithm namespace="algorithm"
                          :disabled="isFakeMac"
                          :column-label="$i18n.t('Algorithm')"
    />

    <form-group-pool-backend namespace="pool_backend"
                             :disabled="isFakeMac"
                             :column-label="$i18n.t('DHCP Pool Backend Type')"
    />

    <form-group-dhcp-start namespace="dhcp_start"
                           :disabled="isFakeMac"
                           :column-label="$i18n.t('Starting IP Address')"
    />

    <form-group-dhcp-end namespace="dhcp_end"
                         :disabled="isFakeMac"
                         :column-label="$i18n.t('Ending IP Address')"
    />

    <form-group-dhcp-default-lease-time namespace="dhcp_default_lease_time"
                                        :disabled="isFakeMac"
                                        :column-label="$i18n.t('Default Lease Time')"
    />

    <form-group-dhcp-max-lease-time namespace="dhcp_max_lease_time"
                                    :disabled="isFakeMac"
                                    :column-label="$i18n.t('Max Lease Time')"
    />

    <form-group-ip-reserved namespace="ip_reserved"
                            :disabled="isFakeMac"
                            :column-label="$i18n.t('IP Addresses reserved')"
                            :text="$i18n.t('Range like 192.168.0.1-192.168.0.20 and or IP like 192.168.0.22,192.168.0.24 will be excluded from the DHCP pool.')"
    />

    <form-group-ip-assigned namespace="ip_assigned"
                            :disabled="isFakeMac"
                            :column-label="$i18n.t('IP Addresses assigned')"
                            :text="$i18n.t('List like 00:11:22:33:44:55:192.168.0.12,11:22:33:44:55:66:192.168.0.13.')"
    />

    <form-group-dns namespace="dns"
                    :column-label="$i18n.t('DNS')"
                    :text="$i18n.t('The DNS server(s) of your network. (comma limited)')"
    />

    <form-group-portal-fqdn namespace="portal_fqdn"
                            :disabled="isFakeMac"
                            :column-label="$i18n.t('Portal FQDN')"
                            :text="$i18n.t('Define the FQDN of the portal for this network. Leaving empty will use the FQDN of the PacketFence server.')"
    />

    <form-group-netflow-accounting-enabled v-if="isInline"
                                           namespace="netflow_accounting_enabled"
                                           :column-label="$i18n.t('Netflow Accounting Enabled')"
                                           :text="$i18n.t('Enable Netflow on this network to enable accounting.')"
                                           enabled-value="enabled"
                                           disabled-value="disabled"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAlgorithm,
  FormGroupDescription,
  FormGroupDhcpDefaultLeaseTime,
  FormGroupDhcpEnd,
  FormGroupDhcpMaxLeaseTime,
  FormGroupDhcpStart,
  FormGroupDns,
  FormGroupIdentifier,
  FormGroupIpAssigned,
  FormGroupIpReserved,
  FormGroupNetflowAccountingEnabled,
  FormGroupPoolBackend,
  FormGroupPortalFqdn
} from './'
import {computed, toRefs} from '@vue/composition-api'
import {useFormMetaSchema} from '@/composables/useMeta'

const components = {
  BaseForm,

  FormGroupAlgorithm,
  FormGroupDescription,
  FormGroupDhcpDefaultLeaseTime,
  FormGroupDhcpMaxLeaseTime,
  FormGroupDhcpEnd,
  FormGroupDhcpStart,
  FormGroupDns,
  FormGroupIdentifier,
  FormGroupIpAssigned,
  FormGroupIpReserved,
  FormGroupNetflowAccountingEnabled,
  FormGroupPoolBackend,
  FormGroupPortalFqdn
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
  },
  id: {
    type: String
  }
}

export const setup = (props) => {

  const {
    form,
    meta
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const metaSchema = computed(() => useFormMetaSchema(meta, schema))

  const isInline = computed(() => {
    const {type} = form.value || {}
    return type === 'inlinel2'
  })

  const isFakeMac = computed(() => {
    const {fake_mac_enabled} = form.value || {}
    return fake_mac_enabled === '1'
  })

  return {
    schema: metaSchema,

    isInline,
    isFakeMac
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
