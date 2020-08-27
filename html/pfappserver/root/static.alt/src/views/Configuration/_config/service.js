import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
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
          label: 'api-frontend',
          text: i18n.t('Should api-frontend be managed by PacketFence?'),
          cols: [
            {
              namespace: 'api-frontend',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'galera-autofix',
          text: i18n.t('Should galera-autofix be managed by PacketFence?'),
          cols: [
            {
              namespace: 'galera-autofix',
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
          cols: [
            {
              namespace: 'fingerbank-collector',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'haproxy-admin',
          text: i18n.t(`Should haproxy-admin be started? Keep enabled unless you know what you're doing.`),
          cols: [
            {
              namespace: 'haproxy-admin',
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
          cols: [
            {
              namespace: 'haproxy-db',
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
          cols: [
            {
              namespace: 'haproxy-portal',
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
          cols: [
            {
              namespace: 'httpd_aaa',
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
          cols: [
            {
              namespace: 'httpd_admin',
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
          cols: [
            {
              namespace: 'httpd_collector',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'httpd.admin_dispatcher',
          text: i18n.t(`Should httpd.admin_dispatcher be started? Keep enabled unless you know what you're doing.`),
          cols: [
            {
              namespace: 'httpd_admin_dispatcher',
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
          cols: [
            {
              namespace: 'httpd_dispatcher',
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
          cols: [
            {
              namespace: 'httpd_portal',
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
          cols: [
            {
              namespace: 'httpd_proxy',
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
          cols: [
            {
              namespace: 'httpd_webservices',
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
          cols: [
            {
              namespace: 'iptables',
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
          cols: [
            {
              namespace: 'keepalived',
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
          cols: [
            {
              namespace: 'netdata',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'pfacct',
          text: i18n.t(`Should pfacct be started? Keep enabled unless you know what you're doing.`),
          cols: [
            {
              namespace: 'pfacct',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'pfcertmanager',
          text: i18n.t(`Should pfcertmanager be started? Keep enabled unless you know what you're doing.`),
          cols: [
            {
              namespace: 'pfcertmanager',
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
          cols: [
            {
              namespace: 'pfdhcp',
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
          cols: [
            {
              namespace: 'pfdhcplistener',
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
          cols: [
            {
              namespace: 'pfdhcplistener_packet_size',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'pfdhcplistener_packet_size')
            }
          ]
        },
        {
          label: 'pfdns',
          text: i18n.t('Should pfdns be managed by PacketFence?'),
          cols: [
            {
              namespace: 'pfdns',
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
          cols: [
            {
              namespace: 'pffilter',
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
          cols: [
            {
              namespace: 'pfipset',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'pfcron',
          text: i18n.t(`Should pfcron be started? Keep enabled unless you know what you're doing.`),
          cols: [
            {
              namespace: 'pfcron',
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
          cols: [
            {
              namespace: 'pfperl-api',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'pfpki',
          text: i18n.t(`Should pfpki be started? Keep enabled unless you know what you're doing.`),
          cols: [
            {
              namespace: 'pfpki',
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
          cols: [
            {
              namespace: 'pfqueue',
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
          cols: [
            {
              namespace: 'pfsso',
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
          cols: [
            {
              namespace: 'pfstats',
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
          cols: [
            {
              namespace: 'radiusd',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'radiusd-acct',
          text: i18n.t(`Should radiusd-acct be started? Keep enabled unless you know what you're doing.`),
          cols: [
            {
              namespace: 'radiusd_acct',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'radiusd-auth',
          text: i18n.t(`Should radiusd-auth be started? Keep enabled unless you know what you're doing.`),
          cols: [
            {
              namespace: 'radiusd_auth',
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
          cols: [
            {
              namespace: 'radsniff',
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
          cols: [
            {
              namespace: 'redis_cache',
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
          cols: [
            {
              namespace: 'redis_ntlm_cache',
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
          cols: [
            {
              namespace: 'redis_queue',
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
          cols: [
            {
              namespace: 'snmptrapd',
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
          cols: [
            {
              namespace: 'tc',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'tracking-config',
          text: i18n.t('Should tracking-config be managed by PacketFence?'),
          cols: [
            {
              namespace: 'tracking-config',
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
          cols: [
            {
              namespace: 'winbindd',
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

export const validators = (form = {}, meta = {}) => {
  return {
    pfdhcplistener_packet_size: validatorsFromMeta(meta, 'pfdhcplistener_packet_size', i18n.t('Size'))
  }
}
