<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-api-frontend namespace="api-frontend"
                             column-label="api-frontend"
                             :text="$i18n.t('Should api-frontend be managed by PacketFence?')"
                             enabled-value="enabled"
                             disabled-value="disabled"
    />

    <form-group-galera-autofix namespace="galera-autofix"
                               column-label="galera-autofix"
                               :text="$i18n.t('Should galera-autofix be managed by PacketFence?')"
                               enabled-value="enabled"
                               disabled-value="disabled"
    />

    <form-group-fingerbank-collector namespace="fingerbank-collector"
                                     column-label="fingerbank-collector"
                                     :text="$i18n.t('Should the fingerbank-collector be managed by PacketFence?')"
                                     enabled-value="enabled"
                                     disabled-value="disabled"
    />

    <form-group-haproxy-admin namespace="haproxy-admin"
                              column-label="haproxy-admin"
                              :text="$i18n.t(`Should haproxy-admin be started?`)"
                              enabled-value="enabled"
                              disabled-value="disabled"
    />

    <form-group-haproxy-db namespace="haproxy-db"
                           column-label="haproxy-db"
                           :text="$i18n.t(`Should haproxy-db be started?`)"
                           enabled-value="enabled"
                           disabled-value="disabled"
    />

    <form-group-haproxy-portal namespace="haproxy-portal"
                               column-label="haproxy-portal"
                               :text="$i18n.t(`Should haproxy-portal be started?`)"
                               enabled-value="enabled"
                               disabled-value="disabled"
    />

    <form-group-httpd-aaa namespace="httpd_aaa"
                          column-label="httpd.aaa"
                          :text="$i18n.t(`Should httpd.aaa be started?`)"
                          enabled-value="enabled"
                          disabled-value="disabled"
    />

    <form-group-httpd-admin-dispatcher namespace="httpd_admin_dispatcher"
                                       column-label="httpd.admin_dispatcher"
                                       :text="$i18n.t(`Should httpd.admin_dispatcher be started?`)"
                                       enabled-value="enabled"
                                       disabled-value="disabled"
    />

    <form-group-httpd-dispatcher namespace="httpd_dispatcher"
                                 column-label="httpd.dispatcher"
                                 :text="$i18n.t(`Should httpd.dispatcher be started?`)"
                                 enabled-value="enabled"
                                 disabled-value="disabled"
    />

    <form-group-httpd-portal namespace="httpd_portal"
                             column-label="httpd.portal"
                             :text="$i18n.t(`Should httpd.portal be started?`)"
                             enabled-value="enabled"
                             disabled-value="disabled"
    />

    <form-group-httpd-webservices namespace="httpd_webservices"
                                  column-label="httpd.webservices"
                                  :text="$i18n.t(`Should httpd.webservices be started?`)"
                                  enabled-value="enabled"
                                  disabled-value="disabled"
    />

    <form-group-iptables namespace="iptables"
                         column-label="iptables"
                         :text="$i18n.t(`Should iptables be managed by PacketFence?`)"
                         enabled-value="enabled"
                         disabled-value="disabled"
    />

    <form-group-ip6tables namespace="ip6tables"
                          column-label="ip6tables"
                          :text="$i18n.t(`Should ip6tables be managed by PacketFence?`)"
                          enabled-value="enabled"
                          disabled-value="disabled"
    />

    <form-group-keepalived namespace="keepalived"
                           column-label="keepalived"
                           :text="$i18n.t(`Should keepalived be started?`)"
                           enabled-value="enabled"
                           disabled-value="disabled"
    />

    <form-group-netdata namespace="netdata"
                        column-label="netdata"
                        :text="$i18n.t('Should netdata be managed by PacketFence?')"
                        enabled-value="enabled"
                        disabled-value="disabled"
    />

    <form-group-pfacct namespace="pfacct"
                       column-label="pfacct"
                       :text="$i18n.t(`Should pfacct be started?`)"
                       enabled-value="enabled"
                       disabled-value="disabled"
    />

    <form-group-netflow-address namespace="netflow_address"
                                :column-label="$i18n.t('Netflow address')"
                                :text="$i18n.t(`The network address to listen to listen on. Do not change unless you know what you're doing.`)"
    />

    <form-group-pfdhcp namespace="pfdhcp"
                       column-label="pfdhcp"
                       :text="$i18n.t('Should pfdhcp be managed by PacketFence?')"
                       enabled-value="enabled"
                       disabled-value="disabled"
    />

    <form-group-pfdhcplistener namespace="pfdhcplistener"
                               column-label="pfdhcplistener"
                               :text="$i18n.t(`Should pfdhcplistener be started? Keep enabled unless you know what you're doing`)"
                               enabled-value="enabled"
                               disabled-value="disabled"
    />

    <form-group-pfdhcplistener-packet-size namespace="pfdhcplistener_packet_size"
                                           :column-label="$i18n.t('pfdhcplistener Packet Size')"
                                           :text="$i18n.t(`Set the max size of DHCP packets. Do not change unless you know what you're doing.`)"
    />

    <form-group-pfdns namespace="pfdns"
                      column-label="pfdns"
                      :text="$i18n.t('Should pfdns be managed by PacketFence?')"
                      enabled-value="enabled"
                      disabled-value="disabled"
    />

    <form-group-pffilter namespace="pffilter"
                         column-label="pffilter"
                         :text="$i18n.t('Should pffilter be managed by PacketFence?')"
                         enabled-value="enabled"
                         disabled-value="disabled"
    />

    <form-group-pfipset namespace="pfipset"
                        column-label="pfipset"
                        :text="$i18n.t('Should pfipset be managed by PacketFence?')"
                        enabled-value="enabled"
                        disabled-value="disabled"
    />

    <form-group-pfcron namespace="pfcron"
                       column-label="pfcron"
                       :text="$i18n.t(`Should pfcron be started?`)"
                       enabled-value="enabled"
                       disabled-value="disabled"
    />

    <form-group-pfperl-api namespace="pfperl-api"
                           column-label="pfperl-api"
                           :text="$i18n.t(`Should pfperl-api be started?`)"
                           enabled-value="enabled"
                           disabled-value="disabled"
    />

    <form-group-pfpki namespace="pfpki"
                      column-label="pfpki"
                      :text="$i18n.t(`Should pfpki be started?`)"
                      enabled-value="enabled"
                      disabled-value="disabled"
    />

    <form-group-pfqueue-backend namespace="pfqueue-backend"
                               column-label="pfqueue-backend"
                               :text="$i18n.t(`Should pfqueue-backend be started?`)"
                               enabled-value="enabled"
                               disabled-value="disabled"
    />

    <form-group-pfqueue-go namespace="pfqueue-go"
                           column-label="pfqueue-go"
                           :text="$i18n.t(`Should pfqueue-go be started?`)"
                           enabled-value="enabled"
                           disabled-value="disabled"
    />

    <form-group-pfsso namespace="pfsso"
                      column-label="pfsso"
                      :text="$i18n.t('Should pfsso be managed by PacketFence?')"
                      enabled-value="enabled"
                      disabled-value="disabled"
    />

    <form-group-pfstats namespace="pfstats"
                        column-label="pfstats"
                        :text="$i18n.t('Should pfstats be managed by PacketFence?')"
                        enabled-value="enabled"
                        disabled-value="disabled"
    />

    <form-group-proxysql namespace="proxysql"
                         column-label="proxysql"
                         :text="$i18n.t('Should proxysql be managed by PacketFence?')"
                         enabled-value="enabled"
                         disabled-value="disabled"
    />

    <form-group-radiusd namespace="radiusd"
                        column-label="radiusd"
                        :text="$i18n.t('Should radiusd be managed by PacketFence?')"
                        enabled-value="enabled"
                        disabled-value="disabled"
    />

    <form-group-radiusd-acct namespace="radiusd_acct"
                             column-label="radiusd-acct"
                             :text="$i18n.t(`Should radiusd-acct be started?`)"
                             enabled-value="enabled"
                             disabled-value="disabled"
    />

    <form-group-radiusd-auth namespace="radiusd_auth"
                             column-label="radiusd_auth"
                             :text="$i18n.t(`Should radiusd-auth be started?`)"
                             enabled-value="enabled"
                             disabled-value="disabled"
    />

    <form-group-radsniff namespace="radsniff"
                         column-label="radsniff"
                         :text="$i18n.t('Should radsniff be managed by PacketFence?')"
                         enabled-value="enabled"
                         disabled-value="disabled"
    />

    <form-group-redis-cache namespace="redis_cache"
                            column-label="redis_cache"
                            :text="$i18n.t(`Should Redis for caching be started?`)"
                            enabled-value="enabled"
                            disabled-value="disabled"
    />

    <form-group-redis-ntlm-cache namespace="redis_ntlm_cache"
                                 column-label="redis_ntlm_cache"
                                 :text="$i18n.t(`Should the Redis NTLM cache be started? Use this if you are enabling an Active Directory NTLM cache.`)"
                                 enabled-value="enabled"
                                 disabled-value="disabled"
    />

    <form-group-redis-queue namespace="redis_queue"
                            column-label="redis_queue"
                            :text="$i18n.t(`Should Redis be started?`)"
                            enabled-value="enabled"
                            disabled-value="disabled"
    />

    <form-group-snmp-trapd namespace="snmptrapd"
                           column-label="snmptrapd"
                           :text="$i18n.t(`Should snmptrapd be started?`)"
                           enabled-value="enabled"
                           disabled-value="disabled"
    />

    <form-group-tracking-config namespace="tracking-config"
                                column-label="tracking-config"
                                :text="$i18n.t('Should tracking-config be managed by PacketFence?')"
                                enabled-value="enabled"
                                disabled-value="disabled"
    />

    <form-group-mysql-probe namespace="mysql-probe"
                            column-label="mysql-probe"
                            :text="$i18n.t(`Should mysql-probe be started?`)"
                            enabled-value="enabled"
                            disabled-value="disabled"
    />

    <form-group-kafka namespace="kafka"
                            column-label="kafka"
                            :text="$i18n.t(`Should Kafka be started? Keep disabled unless you know what you're doing.`)"
                            enabled-value="enabled"
                            disabled-value="disabled"
    />

    <form-group-ntlm-auth-api namespace="ntlm-auth-api"
                            column-label="ntlm-auth-api"
                            :text="$i18n.t(`Should ntlm-auth-api be started?`)"
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
  FormGroupApiFrontend,
  FormGroupFingerbankCollector,
  FormGroupGaleraAutofix,
  FormGroupHaproxyAdmin,
  FormGroupHaproxyDb,
  FormGroupHaproxyPortal,
  FormGroupHttpdAaa,
  FormGroupHttpdAdmin,
  FormGroupHttpdAdminDispatcher,
  FormGroupHttpdDispatcher,
  FormGroupHttpdPortal,
  FormGroupHttpdWebservices,
  FormGroupIp6tables,
  FormGroupIptables,
  FormGroupKeepalived,
  FormGroupMysqlProbe,
  FormGroupNetdata,
  FormGroupNetflowAddress,
  FormGroupPfacct,
  FormGroupPfcron,
  FormGroupPfdhcp,
  FormGroupPfdhcplistener,
  FormGroupPfdhcplistenerPacketSize,
  FormGroupPfdns,
  FormGroupPffilter,
  FormGroupPfipset,
  FormGroupPfperlApi,
  FormGroupPfpki,
  FormGroupPfqueueBackend,
  FormGroupPfqueueGo,
  FormGroupPfsso,
  FormGroupPfstats,
  FormGroupProxysql,
  FormGroupRadiusd,
  FormGroupRadiusdAcct,
  FormGroupRadiusdAuth,
  FormGroupRadsniff,
  FormGroupRedisCache,
  FormGroupRedisNtlmCache,
  FormGroupRedisQueue,
  FormGroupSnmpTrapd,
  FormGroupTrackingConfig,
  FormGroupKafka,
  FormGroupNtlmAuthApi
} from './'

const components = {
  BaseForm,

  FormGroupApiFrontend,
  FormGroupFingerbankCollector,
  FormGroupGaleraAutofix,
  FormGroupHaproxyAdmin,
  FormGroupHaproxyDb,
  FormGroupHaproxyPortal,
  FormGroupHttpdAaa,
  FormGroupHttpdAdmin,
  FormGroupHttpdAdminDispatcher,
  FormGroupHttpdDispatcher,
  FormGroupHttpdPortal,
  FormGroupHttpdWebservices,
  FormGroupIptables,
  FormGroupIp6tables,
  FormGroupKeepalived,
  FormGroupNetdata,
  FormGroupNetflowAddress,
  FormGroupPfacct,
  FormGroupPfcron,
  FormGroupPfdhcp,
  FormGroupPfdhcplistener,
  FormGroupPfdhcplistenerPacketSize,
  FormGroupPfdns,
  FormGroupPffilter,
  FormGroupPfipset,
  FormGroupPfperlApi,
  FormGroupPfpki,
  FormGroupPfqueueBackend,
  FormGroupPfqueueGo,
  FormGroupPfsso,
  FormGroupPfstats,
  FormGroupProxysql,
  FormGroupRadiusd,
  FormGroupRadiusdAcct,
  FormGroupRadiusdAuth,
  FormGroupRadsniff,
  FormGroupRedisCache,
  FormGroupRedisNtlmCache,
  FormGroupRedisQueue,
  FormGroupSnmpTrapd,
  FormGroupTrackingConfig,
  FormGroupKafka,
  FormGroupMysqlProbe,
  FormGroupNtlmAuthApi
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

