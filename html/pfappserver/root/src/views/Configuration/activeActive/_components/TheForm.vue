<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-password namespace="password"
                         :column-label="$i18n.t('Shared Key')"
                         :text="$i18n.t('Shared Key for VRRP protocol (must be the same on all members).')"
    />

    <form-group-virtual-router-identifier namespace="virtual_router_id"
                                          :column-label="$i18n.t('Virtual Router ID')"
                                          :text="$i18n.t('The virtual router id for keepalive. Leave untouched unless you have another keepalive cluster in this network. Must be between 1 and 255.')"
    />

    <form-group-vrrp-unicast namespace="vrrp_unicast"
                             :column-label="$i18n.t('VRRP Unicast')"
                             :text="$i18n.t('Enable keepalived in unicast mode instead of multicast.')"
                             enabled-value="enabled"
                             disabled-value="disabled"
    />

    <form-group-dns-on-vip-only namespace="dns_on_vip_only"
                                :column-label="$i18n.t('pfdns on VIP only')"
                                :text="$i18n.t('Set the name server option in DHCP replies to point only to the VIP in cluster mode rather than to all servers in the cluster.')"
                                enabled-value="enabled"
                                disabled-value="disabled"
    />

    <form-group-gateway-on-vip-only namespace="gateway_on_vip_only"
                                    :column-label="$i18n.t('Gateway on VIP only')"
                                    :text="$i18n.t('Set the gateway option in DHCP replies to point only to the VIP in cluster mode rather than to all servers in the cluster.')"
                                    enabled-value="enabled"
                                    disabled-value="disabled"
    />

    <form-group-centralize-vips namespace="centralize_vips"
                                :column-label="$i18n.t('Centralized virtual IPs')"
                                :text="$i18n.t('Centralize the virtual IP addresses on the same node instead of distributing them on the two first nodes of the cluster.')"
                                enabled-value="enabled"
                                disabled-value="disabled"
    />

    <form-group-centralized-deauth namespace="centralized_deauth"
                                   :column-label="$i18n.t('Centralized access reevaluation')"
                                   :text="$i18n.t('Centralize the deauthentication to the management node of the cluster.')"
                                   enabled-value="enabled"
                                   disabled-value="disabled"
    />

    <form-group-use-vip-for-deauth namespace="use_vip_for_deauth"
                                   :column-label="$i18n.t('Use virtual IP for access reevaluation')"
                                   :text="$i18n.t('Use the virtual IP as the source IP during access reevaluation.')"
                                   enabled-value="enabled"
                                   disabled-value="disabled"
    />

    <form-group-radius-proxy-with-vip namespace="radius_proxy_with_vip"
                                      :column-label="$i18n.t('Proxy RADIUS using virtual IP')"
                                      :text="$i18n.t('Proxy the RADIUS requests received on the RADIUS load balancer using the VIP. When deploying in an environment where the virtual IP is a software load balancer, disable this so that servers proxy the requests using their own IP address')"
                                      enabled-value="enabled"
                                      disabled-value="disabled"
    />

    <form-group-auth-on-management namespace="auth_on_management"
                                   :column-label="$i18n.t('RADIUS authentication on management')"
                                   :text="$i18n.t('Process RADIUS authentication requests on the management server (the current load balancer). Disabling it will make the management server only proxy requests to other servers. Useful if your load balancer cannot handle both tasks. Changing this requires to restart radiusd.')"
                                   enabled-value="enabled"
                                   disabled-value="disabled"
    />

    <form-group-portal-on-management namespace="portal_on_management"
                                     :column-label="$i18n.t('Portal authentication on management')"
                                     :text="$i18n.t('Process captive portal requests requests on the management server (the current load balancer). Disabling it will make the management server only proxy requests to other servers. Useful if your load balancer cannot handle both tasks. Changing this requires to restart haproxy-portal.')"
                                     enabled-value="enabled"
                                     disabled-value="disabled"
    />

    <form-group-firewall-sso-on-management namespace="firewall_sso_on_management"
                                     :column-label="$i18n.t('Process Firewall SSO requests from the management server')"
                                     :text="$i18n.t('Process Firewall SSO only on the managemenr server (the current load balancer).Disabling it will allow each members of the cluster to send Firewall SSO request to firewalls.')"
                                     enabled-value="enabled"
                                     disabled-value="disabled"
    />

    <form-group-conflict-resolution-threshold namespace="conflict_resolution_threshold"
                                              :column-label="$i18n.t('Conflict resolution threshold')"
                                              :text="$i18n.t('Defines the amount of seconds after which pfcron attempts to resolve a configuration version conflict between cluster members. For example, if this is set to 5 minutes, then a resolution will be attempted when the members will be detected running a different version for more than 5 minutes.')"
    />

    <form-group-galera-replication namespace="galera_replication"
                                   :column-label="$i18n.t('Galera replication')"
                                   :text="$i18n.t('Whether or not to activate galera cluster when using a cluster.')"
                                   enabled-value="enabled"
                                   disabled-value="disabled"
    />

    <form-group-galera-replication-username namespace="galera_replication_username"
                                            :column-label="$i18n.t('Galera replication username')"
                                            :text="$i18n.t('Defines the replication username to be used for the MariaDB Galera cluster replication.')"
    />

    <form-group-galera-replication-password namespace="galera_replication_password"
                                            :column-label="$i18n.t('Galera replication password')"
                                            :text="$i18n.t('Defines the replication password to be used for the MariaDB Galera cluster replication.')"
    />

    <form-group-probe-mysql-from-haproxy-db namespace="probe_mysql_from_haproxy_db"
                                            :column-label="$i18n.t('Probe Mysql from haproxy-db')"
                                            :text="$i18n.t('Enable mysql-probe in haproxy-db to detect the availability of the MariaDB servers.')"
                                            enabled-value="enabled"
                                            disabled-value="disabled"
    />

  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAuthOnManagement,
  FormGroupCentralizedDeauth,
  FormGroupCentralizeVips,
  FormGroupConflictResolutionThreshold,
  FormGroupDnsOnVipOnly,
  FormGroupFirewallSsoOnManagement,
  FormGroupGaleraReplication,
  FormGroupGaleraReplicationPassword,
  FormGroupGaleraReplicationUsername,
  FormGroupGatewayOnVipOnly,
  FormGroupPassword,
  FormGroupPortalOnManagement,
  FormGroupProbeMysqlFromHaproxyDb,
  FormGroupRadiusProxyWithVip,
  FormGroupUseVipForDeauth,
  FormGroupVirtualRouterIdentifier,
  FormGroupVrrpUnicast
} from './'

const components = {
  BaseForm,

  FormGroupAuthOnManagement,
  FormGroupCentralizedDeauth,
  FormGroupCentralizeVips,
  FormGroupConflictResolutionThreshold,
  FormGroupDnsOnVipOnly,
  FormGroupFirewallSsoOnManagement,
  FormGroupGatewayOnVipOnly,
  FormGroupGaleraReplication,
  FormGroupGaleraReplicationUsername,
  FormGroupGaleraReplicationPassword,
  FormGroupPassword,
  FormGroupPortalOnManagement,
  FormGroupRadiusProxyWithVip,
  FormGroupUseVipForDeauth,
  FormGroupVirtualRouterIdentifier,
  FormGroupVrrpUnicast,
  FormGroupProbeMysqlFromHaproxyDb
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

