<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-dhcpdetector namespace="dhcpdetector"
      :column-label="$i18n.t('DHCP detector')"
      :text="$i18n.t('If enabled, PacketFence will monitor DHCP-specific items such as rogue DHCP services, DHCP-based OS fingerprinting, computername/hostname resolution, and (optionnally) option-82 location-based information. The monitored DHCP packets are DHCPDISCOVERs and DHCPREQUESTs - both are broadcasts, meaning a span port is not necessary. This feature is highly recommended if the internal network is DHCP-based.')"
    />

    <form-group-dhcp-rate-limiting :namespaces="['dhcp_rate_limiting.interval', 'dhcp_rate_limiting.unit']"
      :column-label="$i18n.t('DHCP detector rate limiting')"
      :text="$i18n.t('Will rate-limit DHCP packets that contain the same information.For example, a DHCPREQUEST for the same MAC/IP will only be processed once in the timeframe configured below. This is independant of the DHCP server/relay handling the packet and is only based on the IP, MAC Address and DHCP type inside the packet. A value of 0 will disable the rate limitation.')"
    />

    <form-group-rogue-dhcp-detection namespace="rogue_dhcp_detection"
      :column-label="$i18n.t('Rogue DHCP detecti')"
      :text="$i18n.t('Tries to identify Rogue DHCP Servers and triggers the 1100010 violation if one is found. This feature is only available if the dhcpdetector is activated.')"
    />

    <form-group-rogueinterval namespace="rogueinterval"
      :column-label="$i18n.t('Rogue interval')"
      :text="$i18n.t('When rogue DHCP server detection is enabled, this parameter defines how often to email administrators. With its default setting of 10, it will email administrators the details of the previous 10 DHCP offers.')"
    />

    <form-group-hostname-change-detection namespace="hostname_change_detection"
      :column-label="$i18n.t('Detect hostname changes')"
      :text="$i18n.t('Will identify hostname changes and send an e-mail with these changes. This can help detect MAC spoofing.')"
    />

    <form-group-connection-type-change-detection namespace="connection_type_change_detection"
      :column-label="$i18n.t('Detect changes in connection type')"
      :text="$i18n.t('Will identify if a device switches from wired to wireless (or the opposite) and send an e-mail with these changes. This can help detect MAC spoofing.')"
    />

    <form-group-dhcpoption82logger namespace="dhcpoption82logger"
      :column-label="$i18n.t('DHCP option82')"
      :text="$i18n.t('If enabled PacketFence will monitor DHCP option82 location-based information. This feature is only available if the dhcpdetector is activated.')"
    />

    <form-group-dhcp-process-ipv6 namespace="dhcp_process_ipv6"
      :column-label="$i18n.t('IPv6 DHCP handling')"
      :text="$i18n.t('IPv6 DHCP packet processing by pfdhcplistener.')"
    />

    <form-group-force-listener-update-on-ack namespace="force_listener_update_on_ack"
      :column-label="$i18n.t('Force Listener update on DHCPACK')"
      :text="$i18n.t('This will only do the iplog update and other DHCP related task on a DHCPACK. You need to make sure the UDP reflector is in place so this works on the production network. This is implicitly activated on registration interfaces on which dhcpd runs.')"
    />

    <form-group-interface-snat namespace="interfaceSNAT"
      :column-label="$i18n.t('SNAT Interface for passthroughs')"
      :text="$i18n.t(`Choose interface(s) where you want to enable SNAT for passthroughs (by default it's the management interface)`)"
    />

    <form-group-staticroutes namespace="staticroutes"
      :column-label="$i18n.t('Static routes')"
      :text="$i18n.t('Add custom static toutes managed by keepalived, one line per static route. (like: 10.0.0.0/24 via 10.0.0.1 dev eth1)')"
    />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupDhcpdetector,
  FormGroupDhcpRateLimiting,
  FormGroupRogueDhcpDetection,
  FormGroupRogueinterval,
  FormGroupHostnameChangeDetection,
  FormGroupConnectionTypeChangeDetection,
  FormGroupDhcpoption82logger,
  FormGroupDhcpProcessIpv6,
  FormGroupForceListenerUpdateOnAck,
  FormGroupInterfaceSnat,
  FormGroupStaticroutes
} from './'

const components = {
  BaseForm,

  FormGroupDhcpdetector,
  FormGroupDhcpRateLimiting,
  FormGroupRogueDhcpDetection,
  FormGroupRogueinterval,
  FormGroupHostnameChangeDetection,
  FormGroupConnectionTypeChangeDetection,
  FormGroupDhcpoption82logger,
  FormGroupDhcpProcessIpv6,
  FormGroupForceListenerUpdateOnAck,
  FormGroupInterfaceSnat,
  FormGroupStaticroutes
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

