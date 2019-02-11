import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'

const {
  ipAddress,
  numeric,
  maxLength
} = require('vuelidate/lib/validators')

/* TODO: make dynamic */
export const pfConfigurationCaptivePortalChosenUnits = [
  { value: 's', text: i18n.t('seconds') },
  { value: 'm', text: i18n.t('minutes') },
  { value: 'h', text: i18n.t('hours') },
  { value: 'D', text: i18n.t('days') },
  { value: 'W', text: i18n.t('weeks') },
  { value: 'M', text: i18n.t('months') },
  { value: 'Y', text: i18n.t('years') }
]

/* TODO: make dynamic */
export const pfConfigurationCaptivePortalURLs = [
  'http://www.gstatic.com/generate_204',
  'http://clients3.google.com/generate_204',
  'http://www.apple.com/library/test/success',
  'http://connectivitycheck.android.com/generate_204',
  'http://connectivitycheck.gstatic.com/generate_204',
  'http://www.msftncsi.com/ncsi.txt',
  'http://www.appleiphonecell.com',
  'http://captive.apple.com',
  'http://captive.roku.com/ok',
  'http://detectportal.firefox.com/success.txt'
]

export const pfConfigurationCaptivePortalViewFields = (context = {}) => {
  const {
    form,
    placeholders
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
              validators: {
                [i18n.t('Invalid IP Address.')]: ipAddress
              }
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
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Positive numbers only.')]: numeric
              }
            },
            {
              key: 'network_detection_initial_delay.unit',
              component: pfFormChosen,
              attrs: {
                placeholder: i18n.t('Choose Unit'),
                collapseObject: true,
                trackBy: 'value',
                label: 'text',
                options: pfConfigurationCaptivePortalChosenUnits
              }
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
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Positive numbers only.')]: numeric
              }
            },
            {
              key: 'network_detection_retry_delay.unit',
              component: pfFormChosen,
              attrs: {
                placeholder: i18n.t('Choose Unit'),
                collapseObject: true,
                trackBy: 'value',
                label: 'text',
                options: pfConfigurationCaptivePortalChosenUnits
              }
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
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Positive numbers only.')]: numeric
              }
            },
            {
              key: 'network_redirect_delay.unit',
              component: pfFormChosen,
              attrs: {
                placeholder: i18n.t('Choose Unit'),
                collapseObject: true,
                trackBy: 'value',
                label: 'text',
                options: pfConfigurationCaptivePortalChosenUnits
              }
            }
          ]
        },
        {
          label: i18n.t('IMG path'),
          text: i18n.t('This is the path where the gif is on the webserver to detect if the network accesshas been enabled.'),
          fields: [
            {
              key: 'image_path',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
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
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Positive numbers only.')]: numeric
              }
            }
          ]
        },
        {
          label: i18n.t('Load balancers IP'),
          text: i18n.t('If the captive portal is put behind load-balancer(s) that act at Layer 7 (HTTP level) effectively doing reverse proxying then the captive portal no longer sees the IP of the node trying to access the portal. In that case, the load-balancers must do SSL offloading and add a X-Forwarded-By header in the HTTP traffic they forward to PacketFence. Most do by default. Then in this parameter you must specify the IP of the various load balancers. This will instruct the captive portal to look for client IPs in the X-Forwarded-For instead of the actual TCP session when it matches an IP in the list. Format is a comma separated list of IPs. Note: Apache access log format is not changed to automatically log the X-Forwarded-By header. Modify conf/httpd.conf.d/captive-portal-common.conf to use load balanced combined instead of combined in CustomLog statement.'),
          fields: [
            {
              key: 'request_timeout',
              component: pfFormTextarea,
              attrs: {
                rows: 3
              },
              validators: {
                 [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
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
          text: i18n.t('When enabled the /status page will only be available on theproduction network. By default this is disabled.'),
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
          fields: [
            {
              component: pfFormHtml,
              attrs: {
                html: () => {
                  let html = []
                  html.push('<div class="bg-light p-3 text-white">')
                  html.push(`<strong class="mr-1 text-dark">${i18n.t('Built-in Captive Portal detection mechanism URLs:')}</strong> `)
                  pfConfigurationCaptivePortalURLs.forEach(url => {
                    html.push(`<span class="badge badge-info mr-1">${url}</span> `)
                  })
                  html.push('</div>')
                  return html.join('')
                }
              }
            }
          ]
        },
        {
          label: null,
          text: i18n.t('Comma-delimited list of URLs known to be used by devices to detect the presence of a captive portal and trigger their captive portal mechanism.'),
          fields: [
            {
              key: 'detection_mecanism_urls',
              component: pfFormTextarea,
              attrs: {
                rows: 5
              },
              validators: {
                 [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
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
          text: i18n.t('Temporarily deny access to a user that performs too many requests on the captive portal on invalid URLsRequires to restart haproxy-portal in order to apply the change.'),
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
          text: i18n.t('Amount of requests on invalid URLs after which the rate limiting will kick in for this device.Requires to restart haproxy-portal in order to apply the change.'),
          fields: [
            {
              key: 'rate_limiting_threshold',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Positive numbers only.')]: numeric
              }
            }
          ]
        },
        {
          label: i18n.t('Other domain names'),
          text: i18n.t('Other domain names under which the captive portal responds.Requires to restart haproxy-portal to be fully effective.'),
          fields: [
            {
              key: 'other_domain_names',
              component: pfFormTextarea,
              attrs: {
                rows: 5
              },
              validators: {
                 [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationCaptivePortalViewDefaults = (context = {}) => {
  return {}
}

export const pfConfigurationCaptivePortalViewPlaceholders = (context = {}) => {
  return {}
}
