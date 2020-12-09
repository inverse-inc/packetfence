import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('DHCP detector'),
          text: i18n.t('If enabled, PacketFence will monitor DHCP-specific items such as rogue DHCP services, DHCP-based OS fingerprinting, computername/hostname resolution, and (optionnally) option-82 location-based information. The monitored DHCP packets are DHCPDISCOVERs and DHCPREQUESTs - both are broadcasts, meaning a span port is not necessary. This feature is highly recommended if the internal network is DHCP-based.'),
          cols: [
            {
              namespace: 'dhcpdetector',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('DHCP detector rate limiting'),
          text: i18n.t('Will rate-limit DHCP packets that contain the same information.For example, a DHCPREQUEST for the same MAC/IP will only be processed once in the timeframe configured below. This is independant of the DHCP server/relay handling the packet and is only based on the IP, MAC Address and DHCP type inside the packet. A value of 0 will disable the rate limitation.'),
          cols: [
            {
              namespace: 'dhcp_rate_limiting.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'dhcp_rate_limiting.interval')
            },
            {
              namespace: 'dhcp_rate_limiting.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'dhcp_rate_limiting.unit')
            }
          ]
        },
        {
          label: i18n.t('Rogue DHCP detection'),
          text: i18n.t('Tries to identify Rogue DHCP Servers and triggers the 1100010 violation if one is found. This feature is only available if the dhcpdetector is activated.'),
          cols: [
            {
              namespace: 'rogue_dhcp_detection',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Rogue interval'),
          text: i18n.t('When rogue DHCP server detection is enabled, this parameter defines how often to email administrators. With its default setting of 10, it will email administrators the details of the previous 10 DHCP offers.'),
          cols: [
            {
              namespace: 'rogueinterval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'rogueinterval')
            }
          ]
        },
        {
          label: i18n.t('Detect hostname changes'),
          text: i18n.t('Will identify hostname changes and send an e-mail with these changes. This can help detect MAC spoofing.'),
          cols: [
            {
              namespace: 'hostname_change_detection',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Detect changes in connection type'),
          text: i18n.t('Will identify if a device switches from wired to wireless (or the opposite) and send an e-mail with these changes. This can help detect MAC spoofing.'),
          cols: [
            {
              namespace: 'connection_type_change_detection',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('DHCP option82'),
          text: i18n.t('If enabled PacketFence will monitor DHCP option82 location-based information. This feature is only available if the dhcpdetector is activated.'),
          cols: [
            {
              namespace: 'dhcpoption82logger',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('IPv6 DHCP handling'),
          text: i18n.t('IPv6 DHCP packet processing by pfdhcplistener.'),
          cols: [
            {
              namespace: 'dhcp_process_ipv6',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Force Listener update on DHCPACK'),
          text: i18n.t('This will only do the iplog update and other DHCP related task on a DHCPACK. You need to make sure the UDP reflector is in place so this works on the production network. This is implicitly activated on registration interfaces on which dhcpd runs.'),
          cols: [
            {
              namespace: 'force_listener_update_on_ack',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('SNAT Interface for passthroughs'),
          text: i18n.t(`Choose interface(s) where you want to enable SNAT for passthroughs (by default it's the management interface)`),
          cols: [
            {
              namespace: 'interfaceSNAT',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'interfaceSNAT')
            }
          ]
        },
        {
          label: i18n.t('Static routes'),
          text: i18n.t('Add custom static toutes managed by keepalived, one line per static route. (like: 10.0.0.0/24 via 10.0.0.1 dev eth1)'),
          cols: [
            {
              namespace: 'staticroutes',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'staticroutes'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  return {
    dhcp_rate_limiting: {
      interval: validatorsFromMeta(meta, 'dhcp_rate_limiting.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'dhcp_rate_limiting.unit', i18n.t('Unit'))
    },
    rogueinterval: validatorsFromMeta(meta, 'rogueinterval', i18n.t('Interval')),
    interfaceSNAT: validatorsFromMeta(meta, 'interfaceSNAT', i18n.t('Interface')),
    staticroutes: validatorsFromMeta(meta, 'staticroutes', i18n.t('Static routes'))
  }
}
