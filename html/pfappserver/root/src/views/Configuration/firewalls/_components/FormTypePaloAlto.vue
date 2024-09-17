<template>
  <base-form
    :form="form"
    :isLoading="isLoading"
    :meta="meta"
    :schema="schema"
  >
    <form-group-identifier :column-label="$i18n.t('Hostname or IP Address')"
                           :disabled="!isNew && !isClone"
                           namespace="id"
    />

    <form-group-vsys :column-label="$i18n.t('Vsys')"
                     :text="$i18n.t('Please define the Virtual System number. This only has an effect when used with the HTTP transport.')"
                     namespace="vsys"
    />

    <form-group-transport :column-label="$i18n.t('Transport')"
                          namespace="transport"
    />

    <form-group-port :column-label="$i18n.t('Port of the service')"
                     :text="$i18n.t('If you use an alternative port, please specify. This parameter is ignored when the Syslog transport is selected.')"
                     namespace="port"
    />

    <form-group-password :column-label="$i18n.t('Secret or Key')"
                         :text="$i18n.t('If using the HTTP transport, specify the password for the Palo Alto API.')"
                         namespace="password"
    />

    <form-group-categories :column-label="$i18n.t('Roles')"
                           :text="$i18n.t('Nodes with the selected roles will be affected.')"
                           namespace="categories"
    />

    <form-group-networks :column-label="$i18n.t('Networks on which to do SSO')"
                         :text="$i18n.t('Comma delimited list of networks on which the SSO applies.\nFormat : 192.168.0.0/24')"
                         namespace="networks"
    />

    <form-group-cache-updates :column-label="$i18n.t('Cache updates')"
                              :text="$i18n.t(`Enable this to debounce updates to the Firewall.\nBy default, PacketFence will send a SSO on every DHCP request for every device. Enabling this enables 'sleep' periods during which the update is not sent if the informations stay the same.`)"
                              disabled-value="disabled"
                              enabled-value="enabled"
                              namespace="cache_updates"
    />

    <form-group-cache-timeout :column-label="$i18n.t('Cache timeout')"
                              :text="$i18n.t(`Adjust the 'Cache timeout' to half the expiration delay in your firewall.\nYour DHCP renewal interval should match this value.`)"
                              namespace="cache_timeout"
    />

    <form-group-username-format :column-label="$i18n.t('Username format')"
                                :text="$i18n.t('Defines how to format the username that is sent to your firewall. $username represents the username and $realm represents the realm of your user if applicable. $pf_username represents the unstripped username as it is stored in the PacketFence database. If left empty, it will use the username as stored in PacketFence (value of $pf_username).')"
                                namespace="username_format"
    />

    <form-group-default-realm :column-label="$i18n.t('Default realm')"
                              :text="$i18n.t('The default realm to be used while formatting the username when no realm can be extracted from the username.')"
                              namespace="default_realm"
    />

    <form-group-use-connector :column-label="$i18n.t('Use Connector')"
                              :text="$i18n.t('Use the available PacketFence connectors to connect to this authentication source. By default, a local connector is hosted on this server. Using remote connectors is only supported on a standalone instance at the moment.')"
                              disabled-value="0"
                              enabled-value="1"
                              namespace="use_connector"
    />

    <form-group-sso-on-access-reevaluation namespace="sso_on_access_reevaluation"
                                           :column-label="$i18n.t('SSO on access reevaluation')"
                                           :text="$i18n.t('Trigger Single-Sign-On (Firewall SSO) on access reevaluation.')"
                                           disabled-value="0"
                                           enabled-value="1"
    />

    <form-group-sso-on-accounting namespace="sso_on_accounting"
                                  :column-label="$i18n.t('SSO on accounting')"
                                  :text="$i18n.t('Trigger Single-Sign-On (Firewall SSO) on accounting start/interim/stop.')"
                                  disabled-value="0"
                                  enabled-value="1"
    />
    
    <form-group-act-on-accounting-stop namespace="act_on_accounting_stop"
                                       :column-label="$i18n.t('SSO on accounting stop')"
                                       :text="$i18n.t('Trigger Single-Sign-On (Firewall SSO) on accounting stop.')"
                                       disabled-value="0"
                                       enabled-value="1"
    />

    <form-group-sso-on-dhcp namespace="sso_on_dhcp"
                            :column-label="$i18n.t('SSO on DHCP')"
                            :text="$i18n.t('Trigger Single-Sign-On (Firewall SSO) on dhcp.')"
                            disabled-value="0"
                            enabled-value="1"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {
  FormGroupActOnAccountingStop,
  FormGroupCacheTimeout,
  FormGroupCacheUpdates,
  FormGroupCategories,
  FormGroupDefaultRealm,
  FormGroupIdentifier,
  FormGroupNetworks,
  FormGroupPassword,
  FormGroupPort,
  FormGroupTransport,
  FormGroupUseConnector,
  FormGroupUsernameFormat,
  FormGroupVsys,
  FormGroupSsoOnAccessReevaluation,
  FormGroupSsoOnAccounting,
  FormGroupSsoOnDhcp,
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,

  FormGroupActOnAccountingStop,
  FormGroupCacheTimeout,
  FormGroupCacheUpdates,
  FormGroupCategories,
  FormGroupDefaultRealm,
  FormGroupIdentifier,
  FormGroupNetworks,
  FormGroupPassword,
  FormGroupPort,
  FormGroupTransport,
  FormGroupUseConnector,
  FormGroupUsernameFormat,
  FormGroupVsys,
  FormGroupSsoOnAccessReevaluation,
  FormGroupSsoOnAccounting,
  FormGroupSsoOnDhcp,
}

// @vue/component
export default {
  name: 'form-type-palo-alto',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
