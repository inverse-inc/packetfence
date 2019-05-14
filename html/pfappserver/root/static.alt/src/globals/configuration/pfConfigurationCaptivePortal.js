import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

const {
  ipAddress
} = require('vuelidate/lib/validators')

export const pfConfigurationCaptivePortalViewFields = (context = {}) => {
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
          label: i18n.t('Network detection'),
          text: i18n.t('Enable the automatic network detection feature for registration auto-redirect.'),
          fields: [
            {
              key: 'network_detection',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('IP'),
          text: i18n.t(`This IP is used as the webserver who hosts the common/network-access-detection.gif which is used to detect if network access was enabled. It cannot be a domain name since it is used in registration or quarantine where DNS is blackholed. It is recommended that you allow your users to reach your PacketFence server and put your LAN's PacketFence IP. By default we will make this reach PacketFence's website as an easy solution.`),
          fields: [
            {
              key: 'network_detection_ip',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'network_detection_ip'),
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'network_detection_ip', 'IP'),
                ...{
                  [i18n.t('Invalid IP.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Detection image path'),
          text: i18n.t('This is the path where the gif is on the webserver to detect if the network access has been enabled.'),
          fields: [
            {
              key: 'image_path',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'image_path'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'image_path', 'Path')
            }
          ]
        },
        {
          label: i18n.t('Initial delay'),
          text: i18n.t('The amount of time before network connectivity detection is started.'),
          fields: [
            {
              key: 'network_detection_initial_delay.interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'network_detection_initial_delay.interval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'network_detection_initial_delay.interval', 'Interval')
            },
            {
              key: 'network_detection_initial_delay.unit',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'network_detection_initial_delay.unit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'network_detection_initial_delay.unit', 'Unit')
            }
          ]
        },
        {
          label: i18n.t('Retry delay'),
          text: i18n.t('The amount of time between network connectivity detection checks.'),
          fields: [
            {
              key: 'network_detection_retry_delay.interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'network_detection_retry_delay.interval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'network_detection_retry_delay.interval', 'Interval')
            },
            {
              key: 'network_detection_retry_delay.unit',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'network_detection_retry_delay.unit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'network_detection_retry_delay.unit', 'Unit')
            }
          ]
        },
        {
          label: i18n.t('Redirection delay'),
          text: i18n.t('How long to display the progress bar during trap release. Default value is based on VLAN enforcement techniques. Inline enforcement only users could lower the value.'),
          fields: [
            {
              key: 'network_redirect_delay.interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'network_redirect_delay.interval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'network_redirect_delay.interval', 'Interval')
            },
            {
              key: 'network_redirect_delay.unit',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'network_redirect_delay.unit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'network_redirect_delay.unit', 'Unit')
            }
          ]
        },
        {
          label: i18n.t('Image path'),
          text: i18n.t('This is the path where the gif is on the webserver to detect if the network access has been enabled.'),
          fields: [
            {
              key: 'image_path',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'image_path'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'image_path', 'Path')
            }
          ]
        },
        {
          label: i18n.t('Request timeout'),
          text: i18n.t('The amount of seconds before a request times out in the captive portal.'),
          fields: [
            {
              key: 'request_timeout',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'request_timeout'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'request_timeout', 'Timeout')
            }
          ]
        },
        {
          label: i18n.t('Load balancers IP'),
          text: i18n.t('If the captive portal is put behind load-balancer(s) that act at Layer 7 (HTTP level) effectively doing reverse proxying then the captive portal no longer sees the IP of the node trying to access the portal. In that case, the load-balancers must do SSL offloading and add a X-Forwarded-By header in the HTTP traffic they forward to PacketFence. Most do by default. Then in this parameter you must specify the IP of the various load balancers. This will instruct the captive portal to look for client IPs in the X-Forwarded-For instead of the actual TCP session when it matches an IP in the list. Format is a comma separated list of IPs. Note: Apache access log format is not changed to automatically log the X-Forwarded-By header. Modify conf/httpd.conf.d/captive-portal-common.conf to use load balanced combined instead of combined in CustomLog statement.'),
          fields: [
            {
              key: 'loadbalancers_ip',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'loadbalancers_ip'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'loadbalancers_ip', 'IP')
            }
          ]
        },
        {
          label: i18n.t('Secure redirect'),
          text: i18n.t('Force the captive portal to use HTTPS for all portal clients.Note that clients will be forced to use HTTPS on all URLs.This requires a restart of the httpd.portal process to be fully effective.'),
          fields: [
            {
              key: 'secure_redirect',
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
          fields: [
            {
              key: 'status_only_on_production',
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
          fields: [
            {
              key: 'detection_mecanism_bypass',
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
          fields: [
            {
              key: 'detection_mecanism_urls',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'detection_mecanism_urls'),
                ...{
                  placeholderHtml: true,
                  labelHtml: i18n.t('Built-in Captive Portal detection mechanism URLs'),
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'detection_mecanism_urls', 'URL')
            }
          ]
        },
        {
          label: i18n.t('WISPr redirection capabilities'),
          text: i18n.t('Enable or disable WISPr redirection capabilities on the captive-portal.'),
          fields: [
            {
              key: 'wispr_redirection',
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
          fields: [
            {
              key: 'rate_limiting',
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
          fields: [
            {
              key: 'rate_limiting_threshold',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'rate_limiting_threshold'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'rate_limiting_threshold', 'Threshold')
            }
          ]
        },
        {
          label: i18n.t('Other domain names'),
          text: i18n.t('Other domain names under which the captive portal responds. Requires to restart haproxy-portal to be fully effective.'),
          fields: [
            {
              key: 'other_domain_names',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'other_domain_names'),
                ...{
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'other_domain_names', 'Domains')
            }
          ]
        }
      ]
    }
  ]
}
