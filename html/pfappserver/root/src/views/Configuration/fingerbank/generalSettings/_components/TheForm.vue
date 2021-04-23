<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >

    <b-media v-if="accountInfo"
      class="alert alert-primary text-secondary mx-3" variant="info" md="auto">
      <template v-slot:aside>
        <icon v-if="accountInfo.auth_type === 'github'"
          name="brands/github" scale="2" />
        <icon v-else-if="accountInfo.auth_type === 'local'"
          name="user-circle" scale="2" />
        <icon v-else
          name="user" scale="2" />
      </template>
      <h4 class="d-inline">{{ $t('Account information on api.fingerbank.org') }}</h4>
      <b-button v-if="urlSSO"
        :href="urlSSO" target="_blank"
        size="sm" variant="secondary" class="ml-2 float-right"
      >{{ $t('View complete account profile') }} <icon class="ml-1" name="external-link-alt"/>
      </b-button>
      <b-row align-v="center" class="mt-1">
        <b-col cols="3">
          <small class="text-nowrap">{{ $t('Username') }}</small>
          <p class="mb-0">{{ accountInfo.name }}</p>
        </b-col>
        <b-col cols="3">
          <small class="text-nowrap">{{ $t('Account type') }}</small>
          <p v-if="accountInfo.auth_type === 'github'"
            class="mb-0">Github</p>
          <p v-else-if="accountInfo.auth_type === 'local'"
            class="mb-0">{{ $t('Corporate') }}</p>
          <p v-else
            class="mb-0">{{ $t('Unknown') }}</p>
        </b-col>
        <b-col cols="auto">
          <small class="text-nowrap">{{ $t('Requests in the current hour') }}</small>
          <p class="mb-0">{{ accountInfo.timeframed_requests || 0 }}</p>
        </b-col>
      </b-row>
    </b-media>

    <form-group-upstream-api-key namespace="upstream.api_key"
      :column-label="$i18n.t('API Key')"
      :text="$i18n.t('API key to interact with upstream Fingerbank project. Changing this value requires to restart the Fingerbank collector.')"
    />

    <form-group-upstream-host namespace="upstream.host"
      :column-label="$i18n.t('Upstream API host')"
      :text="$i18n.t('The host on which the Fingerbank API should be reached.')"
    />

    <form-group-upstream-port namespace="upstream.port"
      :column-label="$i18n.t('Upstream API port')"
      :text="$i18n.t('The port on which the Fingerbank API should be reached')"
    />

    <form-group-upstream-use-https namespace="upstream.use_https"
      :column-label="$i18n.t('Upstream API HTTPS')"
      :text="$i18n.t('Whether or not HTTPS should be used to communicate with the Fingerbank API.')"
    />

    <form-group-upstream-database-path namespace="upstream.db_path"
      :column-label="$i18n.t('Database API path')"
      :text="$i18n.t('Path used to fetch the database on the Fingerbank API.')"
    />

    <form-group-upstream-sqlite-database-retention namespace="upstream.sqlite_db_retention"
      :column-label="$i18n.t('Retention of the upstream sqlite DB')"
      :text="$i18n.t('Amount of upstream databases to retain on disk in db/. Should be at least one in case any running processes are still pointing on the old file descriptor of the database.')"
    />

    <form-group-collector-host namespace="collector.host"
      :column-label="$i18n.t('Collector host')"
      :text="$i18n.t('The host on which the Fingerbank collector should be reached.')"
    />

    <form-group-collector-port namespace="collector.port"
      :column-label="$i18n.t('Collector port')"
      :text="$i18n.t('The port on which the Fingerbank collector should be reached.')"
    />

    <form-group-collector-use-https namespace="collector.use_https"
      :column-label="$i18n.t('Collector HTTPS')"
      :text="$i18n.t('Whether or not HTTPS should be used to communicate with the collector.')"
    />

    <form-group-collector-inactive-endpoints-expiration namespace="collector.inactive_endpoints_expiration"
      :column-label="$i18n.t('Inactive endpoints expiration')"
      :text="$i18n.t('Amount of hours after which the information inactive endpoints should be removed from the collector.')"
    />

    <form-group-collector-arp-lookup namespace="collector.arp_lookup"
      :column-label="$i18n.t('ARP lookups by the collector')"
      :text="$i18n.t('Whether or not the collector should perform ARP lookups for devices it doesn't have DHCP information. Use only on small deployments.')"
    />

    <form-group-collector-network-behavior-analysis namespace="collector.network_behavior_analysis"
      :column-label="$i18n.t('Network behavior analysis')"
      :text="$i18n.t('Whether or not the collector should perform network behavior analysis of the endpoints it sees.')"
    />

    <form-group-collector-query-cache-time namespace="collector.query_cache_time"
      :column-label="$i18n.t('Query cache time in the collector')"
      :text="$i18n.t('Amount of minutes for which the collector API query results are cached.')"
    />

    <form-group-collector-database-persistence-interval namespace="collector.db_persistence_interval"
      :column-label="$i18n.t('Database persistence interval')"
      :text="$i18n.t('Interval in seconds at which the collector will persist its databases.')"
    />

    <form-group-collector-cluster-resync-interval namespace="collector.cluster_resync_interval"
      :column-label="$i18n.t('Cluster resync interval')"
      :text="$i18n.t('Interval in seconds at which the collector will fully resynchronize with its peers when in cluster mode. The collector synchronizes in real-time, so this only acts as a safety net when there is a communication error between the collectors.')"
    />

    <form-group-query-record-unmatched namespace="query.record_unmatched"
      :column-label="$i18n.t('Record Unmatched Parameters')"
      :text="$i18n.t('Should the local instance of Fingerbank record unmatched parameters so that it will be possible to submit thoses unmatched parameters to the upstream Fingerbank project for contribution.')"
    />

    <form-group-proxy-use-proxy namespace="proxy.use_proxy"
      :column-label="$i18n.t('Use proxy')"
      :text="$i18n.t('Should Fingerbank interact with WWW using a proxy?')"
    />

    <form-group-proxy-host namespace="proxy.host"
      :column-label="$i18n.t('Proxy Host')"
      :text="$i18n.t('Host the proxy is listening on. Only the host must be specified here without any port or protocol.')"
    />

    <form-group-proxy-port namespace="proxy.port"
      :column-label="$i18n.t('Proxy Port')"
      :text="$i18n.t('Port the proxy is listening on.')"
    />

    <form-group-proxy-verify-ssl namespace="proxy.verify_ssl"
      :column-label="$i18n.t('Verify SSL')"
      :text="$i18n.t('Whether or not to verify SSL when using proxying.')"
    />

  </base-form>
</template>
<script>
import { computed, onMounted } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupUpstreamApiKey,
  FormGroupUpstreamHost,
  FormGroupUpstreamPort,
  FormGroupUpstreamUseHttps,
  FormGroupUpstreamDatabasePath,
  FormGroupUpstreamSqliteDatabaseRetention,
  FormGroupCollectorHost,
  FormGroupCollectorPort,
  FormGroupCollectorUseHttps,
  FormGroupCollectorInactiveEndpointsExpiration,
  FormGroupCollectorArpLookup,
  FormGroupCollectorNetworkBehaviorAnalysis,
  FormGroupCollectorQueryCacheTime,
  FormGroupCollectorDatabasePersistenceInterval,
  FormGroupCollectorClusterResyncInterval,
  FormGroupQueryRecordUnmatched,
  FormGroupProxyUseProxy,
  FormGroupProxyHost,
  FormGroupProxyPort,
  FormGroupProxyVerifySsl
} from './'

const components = {
  BaseForm,

  FormGroupUpstreamApiKey,
  FormGroupUpstreamHost,
  FormGroupUpstreamPort,
  FormGroupUpstreamUseHttps,
  FormGroupUpstreamDatabasePath,
  FormGroupUpstreamSqliteDatabaseRetention,
  FormGroupCollectorHost,
  FormGroupCollectorPort,
  FormGroupCollectorUseHttps,
  FormGroupCollectorInactiveEndpointsExpiration,
  FormGroupCollectorArpLookup,
  FormGroupCollectorNetworkBehaviorAnalysis,
  FormGroupCollectorQueryCacheTime,
  FormGroupCollectorDatabasePersistenceInterval,
  FormGroupCollectorClusterResyncInterval,
  FormGroupQueryRecordUnmatched,
  FormGroupProxyUseProxy,
  FormGroupProxyHost,
  FormGroupProxyPort,
  FormGroupProxyVerifySsl
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

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const schema = computed(() => schemaFn(props))

  onMounted(() => $store.dispatch('$_fingerbank/getAccountInfo'))

  const accountInfo = computed(() => $store.getters['$_fingerbank/accountInfo'])

  const urlSSO = computed(() => {
    if (accountInfo.value) {
      const { name, key, id } = accountInfo.value
      return [
        'https://api.fingerbank.org:443/sso/login?',
        `username=${name}`,
        `key=${key}`,
        `redirect_url=/users/${id}`
      ].join('&')
    }
    return null
  })

  return {
    schema,
    accountInfo,
    urlSSO
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

