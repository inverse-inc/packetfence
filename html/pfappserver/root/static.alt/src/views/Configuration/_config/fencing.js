import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'

export const view = (_, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Wait for redirect'),
          text: i18n.t(`How many seconds the webservice should wait before deassociating or reassigning VLAN. If we don't wait, the device may switch VLAN before it has a chance to load the redirection page.`),
          cols: [
            {
              namespace: 'wait_for_redirect',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'wait_for_redirect')
            }
          ]
        },
        {
          label: i18n.t('Whitelist'),
          text: i18n.t('Comma-separated list of MAC addresses that are immune to isolation. In inline Level 2 enforcement, the firewall is opened for them as if they were registered. This feature will probably be reworked in the future.'),
          cols: [
            {
              namespace: 'whitelist',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'whitelist'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Addresses ranges'),
          text: i18n.t('Address ranges/CIDR blocks that PacketFence will monitor/detect/trap on. Gateway, network, and broadcast addresses are ignored. Comma-separated entries should be of the form\na.b.c.0/24\na.b.c.0-255\na.b.c.0-a.b.c.255\na.b.c.d'),
          cols: [
            {
              namespace: 'range',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'range'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Passthrough'),
          text: i18n.t('When enabled, PacketFence uses pfdns if you defined Passthroughs or Apache mod-proxy if you defined Proxy passthroughs to allow trapped devices to reach web sites. Modifying this parameter requires to restart pfdns and iptables to be fully effective.'),
          cols: [
            {
              namespace: 'passthrough',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Passthroughs Domains'),
          text: i18n.t('Comma-separated list of domains to allow access from the registration VLAN.If no port is specified for the domain (ex: example.com), it opens TCP 80 and 443. You can specify a specific port to open (ex: example.com:tcp:25) which opens port 25 in TCP. When no protocol is specified (ex: example.com:25), this opens the port for both the UDP and TCP protocol. You can specify the same domain with a different port multiple times and they will be combined. The configuration parameter passthrough must be enabled for passthroughs to be effective. These passthroughs are only effective in registration networks, for passthroughs in isolation, use fencing.isolation_passthroughs.'),
          cols: [
            {
              namespace: 'passthroughs',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'passthroughs'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Proxy Passthroughs'),
          text: i18n.t('Comma-separated list of domains to be used with apache passthroughs. The configuration parameter passthrough must be enabled for passthroughs to be effective.'),
          cols: [
            {
              namespace: 'proxy_passthroughs',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'proxy_passthroughs'),
                ...{
                  placeholderHtml: true,
                  labelHtml: i18n.t('Built-in Proxy Passthroughs'),
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Isolation Passthrough'),
          text: i18n.t('When enabled, PacketFence uses pfdns if you defined Isolation Passthroughs to allow trapped devices in isolation state to reach web sites. Modifying this parameter requires to restart pfdns and iptables to be fully effective.'),
          cols: [
            {
              namespace: 'isolation_passthrough',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Isolation Passthroughs Domains'),
          text: i18n.t('Comma-separated list of domains to allow access from the isolation VLAN. If no port is specified for the domain (ex: example.com), it opens TCP 80 and 443.You can specify a specific port to open (ex: example.com:tcp:25) which opens port 25 in TCP. When no protocol is specified (ex: example.com:25), this opens the port for both the UDP and TCP protocol. You can specify the same domain with a different port multiple times and they will be combined. The configuration parameter isolation_passthrough must be enabled for passthroughs to be effective.'),
          cols: [
            {
              namespace: 'isolation_passthroughs',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'isolation_passthroughs'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Proxy Interception'),
          text: i18n.t('If enabled, we will intercept proxy request on the specified ports to forward to the captive portal.'),
          cols: [
            {
              namespace: 'interception_proxy',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Proxy Interception Port'),
          text: i18n.t('Comma-separated list of port used by proxy interception.'),
          cols: [
            {
              namespace: 'interception_proxy_port',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'interception_proxy_port'),
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

export const validators = (_, meta = {}) => {
  return {
    wait_for_redirect: validatorsFromMeta(meta, 'wait_for_redirect', i18n.t('Wait')),
    whitelist: validatorsFromMeta(meta, 'whitelist', i18n.t('Whitelist')),
    range: validatorsFromMeta(meta, 'range', i18n.t('Range')),
    passthroughs: validatorsFromMeta(meta, 'passthroughs', i18n.t('Domains')),
    proxy_passthroughs: validatorsFromMeta(meta, 'proxy_passthroughs', i18n.t('Domains')),
    isolation_passthroughs: validatorsFromMeta(meta, 'isolation_passthroughs', i18n.t('Domains')),
    interception_proxy_port: validatorsFromMeta(meta, 'interception_proxy_port', i18n.t('Ports'))
  }
}
