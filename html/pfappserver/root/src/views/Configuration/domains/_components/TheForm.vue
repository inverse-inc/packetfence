<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('Settings')" active>

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


        <form-group-machine-account-password namespace="machine_account_password"
                                             :column-label="$i18n.t('Machine account password')"
                                             :text="$i18n.t(`Password / password hash of the machine account, password will be hashed and stored in config files, you won't be able to retrieve your plain text password once click create or save. type another value to change the password, or leave it as-is`)"
                                             :buttonLabel="$i18n.t('Test Machine account')"
                                             testLabel="Processing"
                                             :test="fn"
        />

        <form-group-bind-dn namespace="bind_dn"
                                      :column-label="$i18n.t('Domain administrator username')"
                                      :text="$i18n.t(`Domain Administrator's Username, PacketFence will only use this to update machine accounts in Active Directory, this will not be saved into config file`)"
        />

        <form-group-bind-pass namespace="bind_pass"
                                          :column-label="$i18n.t('Domain administrator password')"
                                          :text="$i18n.t(`Domain administrator's password, PacketFence will only use this to update machine account in Active Directory, this will not be saved into config file`)"
        />

        <form-group-ntlmv2-only namespace="ntlmv2_only"
                                :column-label="$i18n.t('NTLM v2 only')"
                                :text='$i18n.t(`If you enabled "Send NTLMv2 Response Only. Refuse LM & NTLM" (only allow ntlm v2) in Network Security: LAN Manager authentication level.`)'
                                enabled-value="1"
                                disabled-value="0"
        />

        <form-group-registration namespace="registration"
                                 :column-label="$i18n.t('Allow on registration')"
                                 :text="$i18n.t('If this option is enabled, the device will be able to reach the Active Directory from the registration VLAN.')"
                                 enabled-value="1"
                                 disabled-value="0"
        />
        <b-form-group label-cols="3">
          <div class="alert alert-warning mb-0">
            <strong>{{ $i18n.t('Note:') }}</strong>
            {{
              $i18n.t('"Allow on registration" option requires passthroughs to be enabled as well as configured to allow both the domain DNS name and each domain controllers DNS name (or *.dns name)')
            }}.
            {{ $i18n.t('Example: inverse.local, *.inverse.local') }}
          </div>
        </b-form-group>

      </base-form-tab>
      <base-form-tab :title="$i18n.t('NTLM cache')">

        <form-group-ntlm-cache namespace="ntlm_cache"
                               :column-label="$i18n.t('NTLM cache')"
                               :text="$i18n.t('Enable the NTLM cache for this domain.')"
        />

        <form-group-ntlm-cache-source namespace="ntlm_cache_source"
                                      :column-label="$i18n.t('Source')"
                                      :text="$i18n.t('The source to use to connect to your Active Directory server for NTLM caching.')"
        />

        <form-group-ntlm-cache-expiry namespace="ntlm_cache_expiry"
                                      :column-label="$i18n.t('Expiration')"
                                      :text="$i18n.t('The amount of seconds an entry should be cached.')"
        />

      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import BaseButtonJoin from './BaseButtonJoin'
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
  FormGroupMachineAccountPassword,
  FormGroupBindDn,
  FormGroupBindPass,
  FormGroupNtlmv2Only,
  FormGroupRegistration,

  FormGroupNtlmCache,
  FormGroupNtlmCacheSource,
  FormGroupNtlmCacheExpiry
} from './'

const components = {
  BaseButtonJoin,
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
  FormGroupMachineAccountPassword,
  FormGroupBindDn,
  FormGroupBindPass,
  FormGroupNtlmv2Only,
  FormGroupRegistration,

  FormGroupNtlmCache,
  FormGroupNtlmCacheSource,
  FormGroupNtlmCacheExpiry
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

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const schema = computed(() => schemaFn(props))

  const fn = () => $store.dispatch('$_domains/testMachineAccount', props.form)
  return {
    schema,
    fn
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

