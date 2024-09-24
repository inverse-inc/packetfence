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

    <b-form-group v-show="isType('inlinel2')"
                  label-cols="3">
      <div class="alert alert-warning mb-0">
        <strong>{{ $i18n.t('Note:') }}</strong>
        {{
          $i18n.t(`Remember to enable ip_forward on your operating system for the inline mode to work.`)
        }}
      </div>
    </b-form-group>

    <form-group-additional-listenening-daemons namespace="additional_listening_daemons"
                                               :column-label="$i18n.t('Additional listening daemon(s)')"
                                               :options="daemonOptions"
    />

    <form-group-dns v-show="isType('inlinel2')"
                    namespace="dns"
                    :column-label="$i18n.t('DNS')"
                    :text="$i18n.t('The DNS server(s) of your network. (comma limited)')"
    />

    <form-group-dhcpd-enabled
      v-show="isType('dns-enforcement', 'inlinel2', 'vlan-isolation', 'vlan-registration')"
      namespace="dhcpd_enabled"
      :column-label="$i18n.t('Enable DHCP Server')"
      enabled-value="enabled"
      disabled-value="disabled"
    />

    <template v-if="isType('inlinel2')">
      <form-group-nat-enabled namespace="nat_enabled"
                              :column-label="$i18n.t('Enable NAT')"
                              enabled-value="enabled"
                              disabled-value="disabled"
      />
      <b-form-group v-show="form.nat_enabled !== 'enabled'"
                    label-cols="3">
        <div class="alert alert-warning mb-0">
          <strong>{{ $i18n.t('Note:') }}</strong>
          {{
            $i18n.t(`Since NAT is disabled, PacketFence will adjust iptables to route traffic rather than using NAT. Make sure to add the routes on the system.`)
          }}
        </div>
      </b-form-group>
      <form-group-nat-dns namespace="nat_dns"
                          :column-label="$i18n.t('Proxy DNS')"
                          :text="$i18n.t('Use pfdns to proxy the request to the DNS server defined above when the device is registered.')"
                          enabled-value="enabled"
                          disabled-value="disabled"
      />
    </template>

    <form-group-split-network v-show="isType('inlinel2')"
                              namespace="split_network"
                              :column-label="$i18n.t('Split network by role')"
                              :text="$i18n.t('This will create a small network for each roles.')"
                              enabled-value="enabled"
                              disabled-value="disabled"
    />

    <form-group-reg-network v-show="isType('inlinel2')"
                            namespace="reg_network"
                            :column-label="$i18n.t('Registration IP Address CIDR format')"
                            :text="$i18n.t('When split network by role is enabled then this network will be used as the registration network (example: 192.168.0.1/24).')"
    />

    <form-group-coa v-show="isType('inlinel2')"
                    namespace="coa"
                    :column-label="$i18n.t('Enable CoA')"
                    :text="$i18n.t('Enabling this will send a CoA request to the equipment to reevaluate network access of endpoints.')"
                    enabled-value="enabled"
                    disabled-value="disabled"
    />

    <form-group-netflow-accounting-enabled v-show="isType('inlinel2')"
                                           namespace="netflow_accounting_enabled"
                                           :column-label="$i18n.t('Netflow Accounting Enabled')"
                                           :text="$i18n.t('Enable Netflow on this network to enable accounting.')"
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
  FormGroupCoa,
  FormGroupDhcpdEnabled,
  FormGroupHighAvailability,
  FormGroupIdentifier,
  FormGroupIpAddress,
  FormGroupIpv6Address,
  FormGroupIpv6Prefix,
  FormGroupNatDns,
  FormGroupNatEnabled,
  FormGroupNetflowAccountingEnabled,
  FormGroupNetmask,
  FormGroupRegNetwork,
  FormGroupSplitNetwork,
  FormGroupType,
  FormGroupVlan
} from './'

const components = {
  BaseForm,

  FormGroupAdditionalListeneningDaemons,
  FormGroupCoa,
  FormGroupDhcpdEnabled,
  FormGroupHighAvailability,
  FormGroupIdentifier,
  FormGroupIpAddress,
  FormGroupIpv6Address,
  FormGroupIpv6Prefix,
  FormGroupNatEnabled,
  FormGroupNatDns,
  FormGroupNetflowAccountingEnabled,
  FormGroupNetmask,
  FormGroupRegNetwork,
  FormGroupSplitNetwork,
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

