import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import {
  ipAddress
} from 'vuelidate/lib/validators'

export const view = (_, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('IP address'),
          text: i18n.t('The IP address the portal uses in the registration and isolation networks. Do not change unless you know what you are doing. Changing this requires to restart all of the PacketFence services.'),
          cols: [
            {
              namespace: 'ip_address',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'ip_address')
            }
          ]
        },
        {
          label: i18n.t('Network detection'),
          text: i18n.t('Enable the automatic network detection feature for registration auto-redirect.'),
          cols: [
            {
              namespace: 'network_detection',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Network detection IP'),
          text: i18n.t(`This IP is used as the webserver who hosts the common/network-access-detection.gif which is used to detect if network access was enabled. It cannot be a domain name since it is used in registration or quarantine where DNS is blackholed. It is recommended that you allow your users to reach your PacketFence server and put your LAN's PacketFence IP. By default we will make this reach PacketFence's website as an easy solution.`),
          cols: [
            {
              namespace: 'network_detection_ip',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'network_detection_ip')
            }
          ]
        },
        {
          label: i18n.t('Initial delay'),
          text: i18n.t('The amount of time before network connectivity detection is started.'),
          cols: [
            {
              namespace: 'network_detection_initial_delay.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'network_detection_initial_delay.interval')
            },
            {
              namespace: 'network_detection_initial_delay.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'network_detection_initial_delay.unit')
            }
          ]
        },
        {
          label: i18n.t('Retry delay'),
          text: i18n.t('The amount of time between network connectivity detection checks.'),
          cols: [
            {
              namespace: 'network_detection_retry_delay.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'network_detection_retry_delay.interval')
            },
            {
              namespace: 'network_detection_retry_delay.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'network_detection_retry_delay.unit')
            }
          ]
        },
        {
          label: i18n.t('Redirection delay'),
          text: i18n.t('How long to display the progress bar during trap release. Default value is based on VLAN enforcement techniques. Inline enforcement only users could lower the value.'),
          cols: [
            {
              namespace: 'network_redirect_delay.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'network_redirect_delay.interval')
            },
            {
              namespace: 'network_redirect_delay.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'network_redirect_delay.unit')
            }
          ]
        },
        {
          label: i18n.t('Image path'),
          text: i18n.t('This is the path where the gif is on the webserver to detect if the network access has been enabled.'),
          cols: [
            {
              namespace: 'image_path',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'image_path')
            }
          ]
        },
        {
          label: i18n.t('Request timeout'),
          text: i18n.t('The amount of seconds before a request times out in the captive portal.'),
          cols: [
            {
              namespace: 'request_timeout',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'request_timeout')
            }
          ]
        },
        {
          label: i18n.t('Load balancers IP'),
          text: i18n.t('If the captive portal is put behind load-balancer(s) that act at Layer 7 (HTTP level) effectively doing reverse proxying then the captive portal no longer sees the IP of the node trying to access the portal. In that case, the load-balancers must do SSL offloading and add a X-Forwarded-By header in the HTTP traffic they forward to PacketFence. Most do by default. Then in this parameter you must specify the IP of the various load balancers. This will instruct the captive portal to look for client IPs in the X-Forwarded-For instead of the actual TCP session when it matches an IP in the list. Format is a comma separated list of IPs. Note: Apache access log format is not changed to automatically log the X-Forwarded-By header. Modify conf/httpd.conf.d/captive-portal-common.conf to use load balanced combined instead of combined in CustomLog statement.'),
          cols: [
            {
              namespace: 'loadbalancers_ip',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'loadbalancers_ip'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Secure redirect'),
          text: i18n.t('Force the captive portal to use HTTPS for all portal clients.Note that clients will be forced to use HTTPS on all URLs.This requires a restart of the httpd.portal process to be fully effective.'),
          cols: [
            {
              namespace: 'secure_redirect',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Status URI only on production network'),
          text: i18n.t('When enabled the /status page will only be available on the production network. By default this is disabled.'),
          cols: [
            {
              namespace: 'status_only_on_production',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Captive Portal detection mechanism bypass'),
          text: i18n.t('Bypass the captive-portal detection mechanism of some browsers / end-points by proxying the detection request.'),
          cols: [
            {
              namespace: 'detection_mecanism_bypass',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Captive Portal detection mechanism URLs'),
          text: i18n.t('Comma-separated list of URLs known to be used by devices to detect the presence of a captive portal and trigger their captive portal mechanism.'),
          cols: [
            {
              namespace: 'detection_mecanism_urls',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'detection_mecanism_urls'),
                ...{
                  placeholderHtml: true,
                  labelHtml: i18n.t('Built-in Captive Portal detection mechanism URLs'),
                  rows: 5
                }
              }
            }
          ]
        },
        {
          label: i18n.t('WISPr redirection capabilities'),
          text: i18n.t('Enable or disable WISPr redirection capabilities on the captive-portal.'),
          cols: [
            {
              namespace: 'wispr_redirection',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Rate limiting'),
          text: i18n.t('Temporarily deny access to a user that performs too many requests on the captive portal on invalid URLs. Requires to restart haproxy-portal in order to apply the change.'),
          cols: [
            {
              namespace: 'rate_limiting',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Rate limiting threshold'),
          text: i18n.t('Amount of requests on invalid URLs after which the rate limiting will kick in for this device. Requires to restart haproxy-portal in order to apply the change.'),
          cols: [
            {
              namespace: 'rate_limiting_threshold',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'rate_limiting_threshold')
            }
          ]
        },
        {
          label: i18n.t('Other domain names'),
          text: i18n.t('Other domain names under which the captive portal responds. Requires to restart haproxy-portal to be fully effective.'),
          cols: [
            {
              namespace: 'other_domain_names',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'other_domain_names'),
                ...{
                  rows: 5
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
    ip_address: validatorsFromMeta(meta, 'ip_address', i18n.t('IP address')),
    network_detection_ip: {
      ...validatorsFromMeta(meta, 'network_detection_ip', 'IP'),
      ...{
        [i18n.t('Invalid IP.')]: ipAddress
      }
    },
    network_detection_initial_delay: {
      interval: validatorsFromMeta(meta, 'network_detection_initial_delay.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'network_detection_initial_delay.unit', i18n.t('Unit'))
    },
    network_detection_retry_delay: {
      interval: validatorsFromMeta(meta, 'network_detection_retry_delay.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'network_detection_retry_delay.unit', i18n.t('Unit'))
    },
    network_redirect_delay: {
      interval: validatorsFromMeta(meta, 'network_redirect_delay.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'network_redirect_delay.unit', i18n.t('Unit'))
    },
    image_path: validatorsFromMeta(meta, 'image_path', i18n.t('Path')),
    request_timeout: validatorsFromMeta(meta, 'request_timeout', i18n.t('Timeout')),
    loadbalancers_ip: validatorsFromMeta(meta, 'loadbalancers_ip', 'IP'),
    detection_mecanism_urls: validatorsFromMeta(meta, 'detection_mecanism_urls', 'URL'),
    rate_limiting_threshold: validatorsFromMeta(meta, 'rate_limiting_threshold', i18n.t('Threshold')),
    other_domain_names: validatorsFromMeta(meta, 'other_domain_names', i18n.t('Domains'))
  }
}
