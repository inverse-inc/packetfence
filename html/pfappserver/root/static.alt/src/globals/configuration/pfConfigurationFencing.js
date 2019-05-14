import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationFencingViewFields = (context = {}) => {
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
          label: i18n.t('Wait for redirect'),
          text: i18n.t(`How many seconds the webservice should wait before deassociating or reassigning VLAN. If we don't wait, the device may switch VLAN before it has a chance to load the redirection page.`),
          fields: [
            {
              key: 'wait_for_redirect',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'wait_for_redirect'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'wait_for_redirect', 'Wait')
            }
          ]
        },
        {
          label: i18n.t('Whitelist'),
          text: i18n.t('Comma-separated list of MAC addresses that are immune to isolation. In inline Level 2 enforcement, the firewall is opened for them as if they were registered. This feature will probably be reworked in the future.'),
          fields: [
            {
              key: 'whitelist',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'whitelist'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'whitelist', 'Whitelist')
            }
          ]
        },
        {
          label: i18n.t('Addresses ranges'),
          text: i18n.t('Address ranges/CIDR blocks that PacketFence will monitor/detect/trap on. Gateway, network, and broadcast addresses are ignored. Comma-separated entries should be of the form\na.b.c.0/24\na.b.c.0-255\na.b.c.0-a.b.c.255\na.b.c.d'),
          fields: [
            {
              key: 'range',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'range'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'range', 'Range')
            }
          ]
        },
        {
          label: i18n.t('Passthrough'),
          text: i18n.t('When enabled, PacketFence uses pfdns if you defined Passthroughs or Apache mod-proxy if you defined Proxy passthroughs to allow trapped devices to reach web sites. Modifying this parameter requires to restart pfdns and iptables to be fully effective.'),
          fields: [
            {
              key: 'passthrough',
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
          fields: [
            {
              key: 'passthroughs',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'passthroughs'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'passthroughs', 'Domains')
            }
          ]
        },
        {
          label: i18n.t('Proxy Passthroughs'),
          text: i18n.t('Comma-separated list of domains to be used with apache passthroughs. The configuration parameter passthrough must be enabled for passthroughs to be effective.'),
          fields: [
            {
              key: 'proxy_passthroughs',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'proxy_passthroughs'),
                ...{
                  placeholderHtml: true,
                  labelHtml: i18n.t('Built-in Proxy Passthroughs'),
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'proxy_passthroughs', 'Domains')
            }
          ]
        },
        {
          label: i18n.t('Isolation Passthrough'),
          text: i18n.t('When enabled, PacketFence uses pfdns if you defined Isolation Passthroughs to allow trapped devices in isolation state to reach web sites. Modifying this parameter requires to restart pfdns and iptables to be fully effective.'),
          fields: [
            {
              key: 'isolation_passthrough',
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
          fields: [
            {
              key: 'isolation_passthroughs',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'isolation_passthroughs'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'isolation_passthroughs', 'Domains')
            }
          ]
        },
        {
          label: i18n.t('Proxy Interception'),
          text: i18n.t('If enabled, we will intercept proxy request on the specified ports to forward to the captive portal.'),
          fields: [
            {
              key: 'interception_proxy',
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
          fields: [
            {
              key: 'interception_proxy_port',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'interception_proxy_port'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'interception_proxy_port', 'Ports')
            }
          ]
        }
      ]
    }
  ]
}
