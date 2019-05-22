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
          label: 'api-frontend',
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
          label: 'fingerbank-collector',
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
          label: 'haproxy-db',
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
          label: 'haproxy-portal',
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
          label: 'httpd.aaa',
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
          label: 'httpd.admin',
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
          label: 'httpd.collector',
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
          label: 'httpd.dispatcher',
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
          label: 'httpd.parking',
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
          label: 'httpd.portal',
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
          label: 'httpd.proxy',
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
          label: 'httpd.webservices',
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
          label: 'iptables',
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
          label: 'keepalived',
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
          label: 'netdata',
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
          label: 'pfbandwidthd',
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
          label: 'pfdhcp',
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
          label: 'pfdhcplistener',
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
              validators: pfConfigurationValidatorsFromMeta(meta, 'pfdhcplistener_packet_size', i18n.t('Size'))
            }
          ]
        },
        {
          label: 'pfdns',
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
          label: 'pffilter',
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
          label: 'pfipset',
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
          label: 'pfmon',
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
          label: 'pfperl-api',
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
          label: 'pfqueue',
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
          label: 'pfsso',
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
          label: 'pfstats',
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
        },
        {
          label: 'radiusd',
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
          label: 'radsniff',
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
          label: 'redis_cache',
          text: i18n.t(`Should Redis for caching be started? Keep enabled unless you know what you're doing.`),
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
          label: 'redis_ntlm_cache',
          text: i18n.t(`Should the Redis NTLM cache be started? Use this if you are enabling an Active Directory NTLM cache.`),
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
          label: 'redis_queue',
          text: i18n.t(`Should Redis be started? Keep enabled unless you know what you're doing.`),
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
          label: 'snmptrapd',
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
          label: 'tc',
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
          label: 'winbindd',
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
        }
      ]
    }
  ]
}
