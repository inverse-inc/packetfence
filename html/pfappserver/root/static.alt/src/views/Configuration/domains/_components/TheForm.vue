<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"

    :zzzisLoading="isLoading"

    :isLoading="true"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('Settings')" class="pt-3 px-3" active>

        <form-group-identifier namespace="id"
          :column-label="$i18n.t('Identifier')"
          :disabled="!isNew && !isClone"
        />

        <form-group-workgroup namespace="workgroup"
          :column-label="$i18n.t('Workgroup')"
        />

        <form-group-dns-name namespace="dns_name"
          :column-label="$i18n.t('DNS name of the domain')"
          :text="$i18n.t('The DNS name (FQDN) of the domain.')"
        />

        <form-group-server-name namespace="server_name"
          :column-label="$i18n.t(`This server's name`)"
          :text="$i18n.t(`This server's name (account name) in your Active Directory. Use '%h' to automatically use this server hostname.`)"
        />

        <form-group-sticky-dc namespace="sticky_dc"
          :column-label="$i18n.t('Sticky DC')"
          :text="$i18n.t(`This is used to specify a sticky domain controller to connect to. If not specified, default '*' will be used to connect to any available domain controller.`)"
        />

        <form-group-ad-server namespace="ad_server"
          :column-label="$i18n.t('Active Directory server')"
          :text="$i18n.t('The IP address or DNS name of your Active Directory server.')"
        />

        <form-group-dns-servers namespace="dns_servers"
          :column-label="$i18n.t('DNS server(s)')"
          :text="$i18n.t('The IP address(es) of the DNS server(s) for this domain. Comma delimited if multiple.')"
        />

        <form-group-ou namespace="ou"
          :column-label="$i18n.t('OU')"
          :text="$i18n.t(`Use a specific OU for the PacketFence account. The OU string read from top to bottom without RDNs and delimited by a '/'. (ex: Computers/Servers/Unix).`)"
        />
        <b-form-group label-cols="3">
          <div class="alert alert-warning mb-0">
            <strong>{{ $i18n.t('Note:') }}</strong>
            {{ $i18n.t(`Due to a bug in the current version of samba, you will need to precreate a computer object in the OU you specify above when you're not using the default value ('Computers'). Otherwise you will get the following error: "Failed to join domain: failed to precreate account in ou ou=XYZ,dc=ACME,dc=CORP: No such object".`) }}
          </div>
        </b-form-group>

        <form-group-ntlmv2-only namespace="ntlmv2_only"
          :column-label="$i18n.t('NTLM v2 only')"
          :text='$i18n.t(`If you enabled "Send NTLMv2 Response Only. Refuse LM & NTLM" (only allow ntlm v2) in Network Security: LAN Manager authentication level.`)'
        />

        <form-group-registration namespace="registration"
          :column-label="$i18n.t('Allow on registration')"
          :text="$i18n.t('If this option is enabled, the device will be able to reach the Active Directory from the registration VLAN.')"
        />
        <b-form-group label-cols="3">
          <div class="alert alert-warning mb-0">
            <strong>{{ $i18n.t('Note:') }}</strong>
            {{ $i18n.t('"Allow on registration" option requires passthroughs to be enabled as well as configured to allow both the domain DNS name and each domain controllers DNS name (or *.dns name)') }}.
            {{ $i18n.t('Example: inverse.local, *.inverse.local') }}
          </div>
        </b-form-group>

      </base-form-tab>
      <base-form-tab :title="$i18n.t('NTLM cache')" class="pt-3 px-3">

        <form-group-ntlm-cache namespace="ntlm_cache"
          :column-label="$i18n.t('NTLM cache')"
          :text="$i18n.t('Enable the NTLM cache for this domain.')"
        />

        <form-group-ntlm-cache-source namespace="ntlm_cache_source"
          :column-label="$i18n.t('Source')"
          :text="$i18n.t('The source to use to connect to your Active Directory server for NTLM caching.')"
        />

        <form-group-ntlm-cache-filter namespace="ntlm_cache_filter"
          :column-label="$i18n.t('LDAP filter')"
          :text="$i18n.t('An LDAP query to filter out the users that should be cached.')"
          :max-rows="10"
        />

        <form-group-ntlm-cache-expiry namespace="ntlm_cache_expiry"
          :column-label="$i18n.t('Expiration')"
          :text="$i18n.t('The amount of seconds an entry should be cached. This should be adjusted to twice the value of maintenance.populate_ntlm_redis_cache_interval if using the batch mode.')"
        />

        <form-group-ntlm-cache-batch namespace="ntlm_cache_batch"
          :column-label="$i18n.t('NTLM cache background job')"
          :text="$i18n.t('When this is enabled, all users matching the LDAP filter will be inserted in the cache via a background job (maintenance.populate_ntlm_redis_cache_interval controls the interval).')"
        />

        <form-group-ntlm-cache-batch-one-at-a-time namespace="ntlm_cache_batch_one_at_a_time"
          :column-label="$i18n.t('NTLM cache background job individual fetch')"
          :text="$i18n.t('Whether or not to fetch users on your AD one by one instead of doing a single batch fetch. This is useful when your AD is loaded or experiencing issues during the sync. Note that this makes the batch job much longer and is about 4 times slower when enabled.')"
        />

        <form-group-ntlm-cache-on-connection namespace="ntlm_cache_on_connection"
          :column-label="$i18n.t('NTLM cache on connection')"
          :text="$i18n.t('When this is enabled, an async job will cache the NTLM credentials of the user every time he connects.')"
        />

      </base-form-tab>
    </b-tabs>

<pre>{{ form }}</pre>

  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'

import {
  BaseForm,
  BaseFormTab,
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupWorkgroup,
  FormGroupDnsName,
  FormGroupServerName,
  FormGroupStickyDc,
  FormGroupAdServer,
  FormGroupDnsServers,
  FormGroupOu,
  FormGroupNtlmv2Only,
  FormGroupRegistration,

  FormGroupNtlmCache,
  FormGroupNtlmCacheSource,
  FormGroupNtlmCacheFilter,
  FormGroupNtlmCacheExpiry,
  FormGroupNtlmCacheBatch,
  FormGroupNtlmCacheBatchOneAtATime,
  FormGroupNtlmCacheOnConnection,
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupWorkgroup,
  FormGroupDnsName,
  FormGroupServerName,
  FormGroupStickyDc,
  FormGroupAdServer,
  FormGroupDnsServers,
  FormGroupOu,
  FormGroupNtlmv2Only,
  FormGroupRegistration,

  FormGroupNtlmCache,
  FormGroupNtlmCacheSource,
  FormGroupNtlmCacheFilter,
  FormGroupNtlmCacheExpiry,
  FormGroupNtlmCacheBatch,
  FormGroupNtlmCacheBatchOneAtATime,
  FormGroupNtlmCacheOnConnection
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

