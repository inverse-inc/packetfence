<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier :namespace="(form.master) ? 'master' : 'id'"
                           :column-label="$i18n.t('Interface')"
                           disabled
    />

    <form-group-vlan v-show="isNew || isClone || form.master"
                     namespace="vlan"
                     :column-label="$i18n.t('Virtual LAN ID')"
                     :disabled="!isNew && !isClone"
    />

    <form-group-ip-address namespace="ipaddress"
                           :column-label="$i18n.t('IPv4 Address')"
    />

    <form-group-netmask namespace="netmask"
                        :column-label="$i18n.t('Netmask')"
    />

    <form-group-ipv6-address namespace="ipv6_address"
                             :column-label="$i18n.t('IPv6 Address')"
    />

    <form-group-ipv6-prefix namespace="ipv6_prefix"
                            :column-label="$i18n.t('IPv6 Prefix')"
    />

    <form-group-type namespace="type"
                     :column-label="$i18n.t('Type')"
                     :options="typeOptions"
    />

    <form-group-additional-listenening-daemons namespace="additional_listening_daemons"
                                               :column-label="$i18n.t('Additional listening daemon(s)')"
                                               :options="daemonOptions"
    />

    <form-group-dhcpd-enabled
      v-show="isType('dns-enforcement', 'vlan-isolation', 'vlan-registration')"
      namespace="dhcpd_enabled"
      :column-label="$i18n.t('Enable DHCP Server')"
      enabled-value="enabled"
      disabled-value="disabled"
    />

    <form-group-high-availability v-show="isType('none', 'management')"
                                  namespace="high_availability"
                                  :column-label="$i18n.t('High availability')"
                                  :enabled-value="1"
                                  :disabled-value="0"
    />
  </base-form>
</template>
<script>
import {computed, toRefs} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
import {daemonOptions, typeOptions} from '../config'
import schemaFn from '../schema'
import {
  FormGroupAdditionalListeneningDaemons,
  FormGroupDhcpdEnabled,
  FormGroupHighAvailability,
  FormGroupIdentifier,
  FormGroupIpAddress,
  FormGroupIpv6Address,
  FormGroupIpv6Prefix,
  FormGroupNetmask,
  FormGroupType,
  FormGroupVlan
} from './'

const components = {
  BaseForm,

  FormGroupAdditionalListeneningDaemons,
  FormGroupDhcpdEnabled,
  FormGroupHighAvailability,
  FormGroupIdentifier,
  FormGroupIpAddress,
  FormGroupIpv6Address,
  FormGroupIpv6Prefix,
  FormGroupNetmask,
  FormGroupType,
  FormGroupVlan
}

export const props = {
  id: {
    type: String
  },
  form: {
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

  const {
    form
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const isType = (...types) => {
    const {type} = form.value || {}
    return types.includes(type)
  }

  return {
    schema,
    isType,

    daemonOptions,
    typeOptions
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

