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
                                :text="$i18n.t(`This server's name (machine account name) in the Active Directory. Leaving this to %h will automatically use hostname as machine account name. If PacketFence is running in cluster mode, it will use hostname automatically.`)"
                                :disabled="!isNew && !isClone"
        />

        <form-group-additional-machine-accounts namespace="additional_machine_accounts"
                                :column-label="$i18n.t(`How many additional machine accounts should be created and used`)"
                                :text="$i18n.t(`Additional machine accounts should be created and used to parallel NTLM authentication. PacketFence will use the original machine account name and a short suffix to build the additional machine accounts. E.g. 'primary-1' 'primary-2' if your primiary machine account is set to 'primary'`)"
        />

        <form-group-sticky-dc namespace="sticky_dc"
                              :column-label="$i18n.t('Sticky DC')"
                              :text="$i18n.t(`This is used to specify a sticky domain controller to connect to. If not specified, default '*' will be used to connect to any available domain controller.`)"
        />

        <form-group-ad-fqdn namespace="ad_fqdn"
                            :column-label="$i18n.t('Active Directory FQDN')"
                            :text="$i18n.t('The FQDN of the Active Directory server.')"
        />

        <form-group-ad-server namespace="ad_server"
                              :column-label="$i18n.t('Active Directory IP')"
                              :text="$i18n.t('The IPv4 of the Active Directory server. This field is optional if Active Directory server\'s FQDN is resolvable using DNS servers below. Note: If DNS server, Active Directory Server\'s FQDN and IP are all given, PacketFence will use the resolved IP instead of using the given Active Directory IP.')"
        />

        <form-group-dns-servers namespace="dns_servers"
                                :column-label="$i18n.t('DNS server(s)')"
                                :text="$i18n.t('The IP address(es) of the DNS server(s) for this domain. Comma delimited if multiple. This field is optional if Active Directory server\'s FQDN and IP are specified.')"
        />

        <form-group-ou namespace="ou"
                       :column-label="$i18n.t('OU')"
                       :text="$i18n.t(`Use a specific OU for the PacketFence account. The OU string read from top to bottom without RDNs and delimited by a '/'. (ex: Computers/Servers/Unix).`)"
                       :api-feedback="ouFeedback"
        />


        <template>
          <component namespace="machine_account_password"
                     :is="formGroupComputedMachineAccountPassword"
                     :column-label="$i18n.t('Machine account password')"
                     :text="$i18n.t(`Machine account password hashed after save. Password hashes are ignored, re-enter the original password to resync the machine account.`)"
                     :api-feedback="machineAccountFeedback"
                     v-bind="machineAccountBind"
          />
        </template>

        <form-group-bind-dn namespace="bind_dn"
                                      :column-label="$i18n.t('Domain administrator username')"
                                      :text="$i18n.t(`Domain Administrator's Username, PacketFence will only use this to update machine accounts in Active Directory, this will not be saved into config file.`)"
        />

        <form-group-bind-pass namespace="bind_pass"
                                          :column-label="$i18n.t('Domain administrator password')"
                                          :text="$i18n.t(`Domain administrator's password, PacketFence will only use this to update machine account in Active Directory, this will not be saved into config file.`)"
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
            {{ $i18n.t('If PacketFence is running in cluster mode, an identical, clear-text "Machine account password" must be re-entered to replace the password hash shown in the field when joining 2nd and following nodes to Windows Domain.') }}
          </div>
        </b-form-group>

      </base-form-tab>

      <base-form-tab :title="$i18n.t('NT Key cache')">
        <form-group-nt-key-cache-enabled namespace="nt_key_cache_enabled"
                               :column-label="$i18n.t('Enable NT Key cache')"
                               :text="$i18n.t('Enable NT Key cache for this domain.')"
                               enabled-value="enabled"
                               disabled-value="disabled"
        />
        <form-group-nt-key-cache-expire namespace="nt_key_cache_expire"
                                        :column-label="$i18n.t('Cache key expiration')"
                                        :text="$i18n.t('The amount of seconds an entry should be cached.')"
        />

        <form-group-ad-account-lockout-threshold namespace="ad_account_lockout_threshold"
                                        :column-label="$i18n.t('Account Lockout Threshold')"
                                        :text="$i18n.t('Max attempts before an account get auto lockout. This should be identical with the value set in domain policy')"
        />
        <form-group-ad-account-lockout-duration namespace="ad_account_lockout_duration"
                                        :column-label="$i18n.t('Account Lockout Duration')"
                                        :text="$i18n.t('The amount of minutes that Windows Domain Controller keeps an account being locked after maximum bad login attempts reached. This should be identical with the value set in domain policy.')"
        />
        <form-group-max-allowed-password-attempts-per-device namespace="max_allowed_password_attempts_per_device"
                                                             :column-label="$i18n.t('Max bad logins per device')"
                                                             :text="$i18n.t('Maximum login attempts a device that shares the same account(e.g., an iPhone and Android phone belongs to the same person) can perform before getting auto-banned. This must be less than or equal to Account Lockout Duration')"
        />
        <form-group-ad-reset-account-lockout-counter-after namespace="ad_reset_account_lockout_counter_after"
                                        :column-label="$i18n.t('Lockout count resets after')"
                                        :text="$i18n.t('The amount of minutes before Windows DC resets the bad password count if no bad login attempt was performed.')"
        />
        <form-group-ad-old-password-allowed-period namespace="ad_old_password_allowed_period"
                                        :column-label="$i18n.t('Old Password Allowed Period')"
                                        :text="$i18n.t('The amount of minutes an old password will be accepted in NTLM Authentication after a password change or password reset. The default value is 60. This should be identical with the value set in domain controller.')"
        />
      </base-form-tab>

      <base-form-tab :title="$i18n.t('NTLM cache')">

        <b-alert show variant="danger"
          v-html="$t('This feature will be deprecated.')"></b-alert>

        <form-group-ntlm-cache namespace="ntlm_cache"
                               :column-label="$i18n.t('NTLM cache')"
                               :text="$i18n.t('Enable the NTLM cache for this domain.')"
                               enabled-value="enabled"
                               disabled-value="disabled"
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
import {computed, toRefs} from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupWorkgroup,
  FormGroupDnsName,
  FormGroupServerName,
  FormGroupAdditionalMachineAccounts,
  FormGroupStickyDc,
  FormGroupAdFqdn,
  FormGroupAdServer,
  FormGroupDnsServers,
  FormGroupOu,
  FormGroupMachineAccountPasswordOnly,
  FormGroupMachineAccountPassword,
  FormGroupBindDn,
  FormGroupBindPass,
  FormGroupNtlmv2Only,
  FormGroupRegistration,

  FormGroupNtlmCache,
  FormGroupNtlmCacheSource,
  FormGroupNtlmCacheExpiry,

  FormGroupNtKeyCacheEnabled,
  FormGroupNtKeyCacheExpire,
  FormGroupAdAccountLockoutThreshold,
  FormGroupAdAccountLockoutDuration,
  FormGroupAdResetAccountLockoutCounterAfter,
  FormGroupAdOldPasswordAllowedPeriod,
  FormGroupMaxAllowedPasswordAttemptsPerDevice,

} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupWorkgroup,
  FormGroupDnsName,
  FormGroupServerName,
  FormGroupAdditionalMachineAccounts,
  FormGroupStickyDc,
  FormGroupAdFqdn,
  FormGroupAdServer,
  FormGroupDnsServers,
  FormGroupOu,
  FormGroupMachineAccountPasswordOnly,
  FormGroupMachineAccountPassword,
  FormGroupBindDn,
  FormGroupBindPass,
  FormGroupNtlmv2Only,
  FormGroupRegistration,

  FormGroupNtlmCache,
  FormGroupNtlmCacheSource,
  FormGroupNtlmCacheExpiry,

  FormGroupNtKeyCacheEnabled,
  FormGroupNtKeyCacheExpire,
  FormGroupAdAccountLockoutThreshold,
  FormGroupAdAccountLockoutDuration,
  FormGroupAdResetAccountLockoutCounterAfter,
  FormGroupAdOldPasswordAllowedPeriod,
  FormGroupMaxAllowedPasswordAttemptsPerDevice,
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

  const {
    form
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const schema = computed(() => schemaFn(props))

  const formGroupComputedMachineAccountPassword = computed(() => {

    return (props.isNew) ? FormGroupMachineAccountPasswordOnly : FormGroupMachineAccountPassword
  })

  const isMachineAccountHash = computed(() => {
    const { machine_account_password } = form.value
    return !!machine_account_password && /^[0-9a-f]{32}$/i.test(machine_account_password)
  })

  const machineAccountFeedback = computed(() => {
    if (isMachineAccountHash.value)
      return i18n.t(`Password is hashed. Type a new or existing password to resync the machine account.`)
    return undefined
  })

  const machineAccountBind = computed(() => {
    return ((!isMachineAccountHash.value)
      ? {
        buttonLabel: i18n.t('Test'),
        testLabel: i18n.t('Processing'),
        test: () => $store.dispatch('$_domains/testMachineAccount', { ...props.form, quiet: true })
      }
      : {
        test: false
      }
    )
  })

  const isDefaultOU = computed(() => {
    const { ou } = form.value
    return !!ou && /^computers$/i.test(ou) || !ou
  })

  const ouFeedback = computed(() => {
    if (isDefaultOU.value) {
      return undefined
    }
    return i18n.t(`Non-default OU is defined. LDAPS service on port 636 is required in Domain Controller.`)
  })


  return {
    schema,
    formGroupComputedMachineAccountPassword,
    isMachineAccountHash,
    machineAccountFeedback,
    machineAccountBind,
    isDefaultOU,
    ouFeedback
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

