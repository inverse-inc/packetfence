import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationNetworkViewFields = (context = {}) => {
  const {
    options: {
      meta = {}
    }
  } = context
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('DHCP detector'),
          text: i18n.t('If enabled, PacketFence will monitor DHCP-specific items such as rogue DHCP services, DHCP-based OS fingerprinting, computername/hostname resolution, and (optionnally) option-82 location-based information. The monitored DHCP packets are DHCPDISCOVERs and DHCPREQUESTs - both are broadcasts, meaning a span port is not necessary. This feature is highly recommended if the internal network is DHCP-based.'),
          fields: [
            {
              key: 'dhcpdetector',
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
          fields: [
            {
              key: 'dhcp_rate_limiting.interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'dhcp_rate_limiting.interval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'dhcp_rate_limiting.interval', i18n.t('Interval'))
            },
            {
              key: 'dhcp_rate_limiting.unit',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'dhcp_rate_limiting.unit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'dhcp_rate_limiting.unit', i18n.t('Unit'))
            }
          ]
        },
        {
          label: i18n.t('Rogue DHCP detection'),
          text: i18n.t('Tries to identify Rogue DHCP Servers and triggers the 1100010 violation if one is found. This feature is only available if the dhcpdetector is activated.'),
          fields: [
            {
              key: 'rogue_dhcp_detection',
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
          fields: [
            {
              key: 'rogueinterval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'rogueinterval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'rogueinterval', i18n.t('Interval'))
            }
          ]
        },
        {
          label: i18n.t('Detect hostname changes'),
          text: i18n.t('Will identify hostname changes and send an e-mail with these changes. This can help detect MAC spoofing.'),
          fields: [
            {
              key: 'hostname_change_detection',
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
          fields: [
            {
              key: 'connection_type_change_detection',
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
          fields: [
            {
              key: 'dhcpoption82logger',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('network.dhcp_process_ipv6'),
          text: i18n.t('Enable/disable ipv6 dhcp packets processing by pfdhcplistener.'),
          fields: [
            {
              key: 'dhcp_process_ipv6',
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
          fields: [
            {
              key: 'force_listener_update_on_ack',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('SNAT Interface'),
          text: i18n.t(`Choose interface(s) where you want to enable snat for passthrough (by default it's the management interface)`),
          fields: [
            {
              key: 'interfaceSNAT',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'interfaceSNAT'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'interfaceSNAT', i18n.t('Interface'))
            }
          ]
        }
      ]
    }
  ]
}
