import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationServiceViewFields = (context = {}) => {
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
          label: i18n.t('pfipset'),
          text: i18n.t('Should pfipset be managed by PacketFence?'),
          fields: [
            {
              key: 'pfipset',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfdhcp'),
          text: i18n.t('Should pfdhcp be managed by PacketFence?'),
          fields: [
            {
              key: 'pfdhcp',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('haproxy-portal'),
          text: i18n.t(`Should haproxy-portal be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'haproxy-portal',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('haproxy-db'),
          text: i18n.t(`Should haproxy-db be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'haproxy-db',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pffilter'),
          text: i18n.t('Should pffilter be managed by PacketFence?'),
          fields: [
            {
              key: 'pffilter',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfsso'),
          text: i18n.t('Should pfsso be managed by PacketFence?'),
          fields: [
            {
              key: 'pfsso',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('radiusd'),
          text: i18n.t('Should radiusd be managed by PacketFence?'),
          fields: [
            {
              key: 'radiusd',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('iptables'),
          text: i18n.t(`Should iptables be managed by PacketFence? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'iptables',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfbandwidthd'),
          text: i18n.t('Should pfbandwidthd be managed by PacketFence?'),
          fields: [
            {
              key: 'pfbandwidthd',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('httpd.admin'),
          text: i18n.t(`Should httpd.admin be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'httpd_admin',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('httpd.portal'),
          text: i18n.t(`Should httpd.portal be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'httpd_portal',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('httpd.parking'),
          text: i18n.t(`Should httpd.parking be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'httpd_parking',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfperl-api'),
          text: i18n.t(`Should pfperl-api be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'pfperl-api',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('httpd.webservices'),
          text: i18n.t(`Should httpd.webservices be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'httpd_webservices',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('httpd.collector'),
          text: i18n.t(`Should httpd.collector be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'httpd_collector',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('httpd.dispatcher'),
          text: i18n.t(`Should httpd.dispatcher be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'httpd_dispatcher',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('httpd.aaa'),
          text: i18n.t(`Should httpd.aaa be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'httpd_aaa',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('httpd.proxy'),
          text: i18n.t(`Should httpd.proxy be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'httpd_proxy',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('snmptrapd'),
          text: i18n.t(`Should snmptrapd be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'snmptrapd',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfqueue'),
          text: i18n.t(`Should pfqueue be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'pfqueue',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfmon'),
          text: i18n.t(`Should pfmon be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'pfmon',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('redis_cache'),
          text: i18n.t(`Should redis for caching be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'redis_cache',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('redis_queue'),
          text: i18n.t(`Should redis be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'redis_queue',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('redis_ntlm_cache'),
          text: i18n.t(`Should the redis NTLM cache be started? Use this if you are enabling an Active Directory NTLM cache.`),
          fields: [
            {
              key: 'redis_ntlm_cache',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfdhcplistener'),
          text: i18n.t(`Should pfdhcplistener be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'pfdhcplistener',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfdhcplistener Packet Size'),
          text: i18n.t(`Set the max size of DHCP packetsDo not change unless you know what you are doing`),
          fields: [
            {
              key: 'pfdhcplistener_packet_size',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'pfdhcplistener_packet_size'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'pfdhcplistener_packet_size', 'Size')
            }
          ]
        },
        {
          label: i18n.t('keepalived'),
          text: i18n.t(`Should keepalived be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'keepalived',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('winbindd'),
          text: i18n.t(`Should winbindd be started? Keep enabled unless you know what you're doing.`),
          fields: [
            {
              key: 'winbindd',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('radsniff'),
          text: i18n.t('Should radsniff be managed by PacketFence?'),
          fields: [
            {
              key: 'radsniff',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('fingerbank-collector'),
          text: i18n.t('Should the fingerbank-collector be managed by PacketFence?'),
          fields: [
            {
              key: 'fingerbank-collector',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('routes'),
          text: i18n.t('Should routes be managed by PacketFence?'),
          fields: [
            {
              key: 'routes',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('netdata'),
          text: i18n.t('Should netdata be managed by PacketFence?'),
          fields: [
            {
              key: 'netdata',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('tc'),
          text: i18n.t('Should traffic shaping be managed by PacketFence?'),
          fields: [
            {
              key: 'tc',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfdns'),
          text: i18n.t('Should pfdns be managed by PacketFence?'),
          fields: [
            {
              key: 'pfdns',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('api-frontend'),
          text: i18n.t('Should api-frontend be managed by PacketFence?'),
          fields: [
            {
              key: 'api-frontend',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfstats'),
          text: i18n.t('Should pfstats be managed by PacketFence?'),
          fields: [
            {
              key: 'pfstats',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        }
      ]
    }
  ]
}
