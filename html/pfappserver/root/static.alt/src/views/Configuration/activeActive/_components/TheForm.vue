<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-password namespace="password"
      :column-label="$i18n.t('Shared KEY')"
      :text="$i18n.t('Shared KEY for VRRP protocol (must be the same on all members).')"
    />

    <form-group-virtual-router-identifier namespace="virtual_router_id"
      :column-label="$i18n.t('Virtual Router ID')"
      :text="$i18n.t('The virtual router id for keepalive. Leave untouched unless you have another keepalive cluster in this network. Must be between 1 and 255.')"
    />

    <form-group-vrrp-unicast namespace="vrrp_unicast"
      :column-label="$i18n.t('VRRP Unicast')"
      :text="$i18n.t('Enable keepalived in unicast mode instead of multicast.')"
    />

    <form-group-dns-on-vip-only namespace="dns_on_vip_only"
      :column-label="$i18n.t('pfdns on VIP only')"
      :text="$i18n.t('Set the name server option in DHCP replies to point only to the VIP in cluster mode rather than to all servers in the cluster.')"
    />

    <form-group-centralized-deauth namespace="centralized_deauth"
      :column-label="$i18n.t('Centralized access reevaluation')"
      :text="$i18n.t('Centralize the deauthentication to the management node of the cluster.')"
    />

    <form-group-auth-on-management namespace="auth_on_management"
      :column-label="$i18n.t('RADIUS authentication on management')"
      :text="$i18n.t('Process RADIUS authentication requests on the management server (the current load balancer). Disabling it will make the management server only proxy requests to other servers. Useful if your load balancer cannot handle both tasks. Changing this requires to restart radiusd.')"
    />

    <form-group-conflict-resolution-threshold :namespaces="['conflict_resolution_threshold.interval', 'conflict_resolution_threshold.unit']"
      :column-label="$i18n.t('Conflict resolution threshold')"
      :text="$i18n.t('Defines the amount of seconds after which pfcron attempts to resolve a configuration version conflict between cluster members. For example, if this is set to 5 minutes, then a resolution will be attempted when the members will be detected running a different version for more than 5 minutes.')"
    />

    <form-group-galera-replication namespace="galera_replication"
      :column-label="$i18n.t('Galera replication')"
      :text="$i18n.t('Whether or not to activate galera cluster when using a cluster.')"
    />

    <form-group-galera-replication-username namespace="galera_replication_username"
      :column-label="$i18n.t('Galera replication username')"
      :text="$i18n.t('Defines the replication username to be used for the MariaDB Galera cluster replication.')"
    />

    <form-group-galera-replication-password namespace="galera_replication_password"
      :column-label="$i18n.t('Galera replication password')"
      :text="$i18n.t('Defines the replication password to be used for the MariaDB Galera cluster replication.')"
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
  FormGroupAuthOnManagement,
  FormGroupCenteralizedDeauth,
  FormGroupConflictResolutionThreshold,
  FormGroupDnsOnVipOnly,
  FormGroupGaleraReplication,
  FormGroupGaleraReplicationUsername,
  FormGroupGaleraReplicationPassword,
  FormGroupPassword,
  FormGroupVirtualRouterIdentifier,
  FormGroupVrrpUnicast
} from './'

const components = {
  BaseForm,

  FormGroupAuthOnManagement,
  FormGroupCenteralizedDeauth,
  FormGroupConflictResolutionThreshold,
  FormGroupDnsOnVipOnly,
  FormGroupGaleraReplication,
  FormGroupGaleraReplicationUsername,
  FormGroupGaleraReplicationPassword,
  FormGroupPassword,
  FormGroupVirtualRouterIdentifier,
  FormGroupVrrpUnicast
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

