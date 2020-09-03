<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
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
            <strong>{{ $i18n.t('Important Note:') }}</strong>
            {{ $i18n.t(`Due to a bug in the current version of samba, you will need to precreate a computer object in the OU you specify above when you're not using the default value ('Computers'). Otherwise you will get the following error: "Failed to join domain: failed to precreate account in ou ou=XYZ,dc=ACME,dc=CORP: No such object".`) }}
          </div>
        </b-form-group>

        <form-group-ntlmv2-only namespace="ntlmv2_only"
          :column-label="$i18n.t('ntlmv2 only')"
          :text='$i18n.t(`If you enabled "Send NTLMv2 Response Only. Refuse LM & NTLM" (only allow ntlm v2) in Network Security: LAN Manager authentication level.`)'
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('NTLM cache')" class="pt-3 px-3">

        <form-group-ntlm-cache-filter namespace="ntlm_cache_filter"
          :column-label="$i18n.t('LDAP filter')"
          :text="$i18n.t('An LDAP query to filter out the users that should be cached.')"
          :max-rows="10"
        />

        <form-group-ntlm-cache-expiry namespace="ntlm_cache_expiry"
          :column-label="$i18n.t('Expiration')"
          :text="$i18n.t('The amount of seconds an entry should be cached. This should be adjusted to twice the value of maintenance.populate_ntlm_redis_cache_interval if using the batch mode.')"
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
  //FormGroupRegistration,

  //FormGroupNtlmCache,
  //FormGroupNtlmCacheSource,
  FormGroupNtlmCacheFilter,
  FormGroupNtlmCacheExpiry,
  //FormGroupNtlmCacheBatch,
  //FormGroupNtlmCacheBatchOneAtATime,
  //FormGroupNtlmCacheOnConnection,
} from './'

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
  components: {
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
    //FormGroupRegistration,

    //FormGroupNtlmCache,
    //FormGroupNtlmCacheSource,
    FormGroupNtlmCacheFilter,
    FormGroupNtlmCacheExpiry,
    //FormGroupNtlmCacheBatch,
    //FormGroupNtlmCacheBatchOneAtATime,
    //FormGroupNtlmCacheOnConnection
  },
  props,
  setup
}
</script>

