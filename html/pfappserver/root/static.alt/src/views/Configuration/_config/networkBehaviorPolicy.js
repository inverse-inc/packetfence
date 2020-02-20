import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import { pfFieldType as fieldType } from '@/globals/pfField'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormFields from '@/components/pfFormFields'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasNetworkBehaviorPolicies,
  networkBehaviorPolicyExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = (context = {}) => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'network_behavior_policy', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/network_behavior_policies',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'description', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'network_behavior_policies' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'description', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('Profile Name'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
          cols: [
            {
              namespace: 'description',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'description')
            }
          ]
        },
        {
          label: 'Devices Included',
          text: i18n.t('The list of Fingerbank devices that will be impacted by this Network Behavior Policy. Devices of this list implicitely includes all the childs of the selected devices. Leaving this empty will have all devices impacted by this policy.'),
          cols: [
            {
              namespace: 'devices_included',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'devices_included'),
              validators: validatorsFromMeta(meta, 'devices_included', 'Device')
            }
          ]
        },
        {
          label: 'Devices Excluded',
          text: i18n.t('The list of Fingerbank devices that should not be impacted by this Network Behavior Policy. Devices of this list implicitely includes all the childs of the selected devices.'),
          cols: [
            {
              namespace: 'devices_excluded',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'devices_excluded'),
              validators: validatorsFromMeta(meta, 'devices_excluded', 'Device')
            }
          ]
        },
        {
          label: i18n.t('Watch blacklisted IPs'),
          text: i18n.t('Whether or not the policy should check if the endpoints are communicating with blacklisted IP addresses.'),
          cols: [
            {
              namespace: 'watch_blacklisted_ips',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              },
              validators: validatorsFromMeta(meta, 'watch_blacklisted_ips', 'Watch blacklisted IPs')
            }
          ]
        },
        {
          label: i18n.t('Whitelisted IPs'),
          text: i18n.t('Which IPs (can be CIDR) to ignore when checking against the blacklisted IPs list'),
          cols: [
            {
              namespace: 'whitelisted_ips',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'whitelisted_ips'),
              validators: validatorsFromMeta(meta, 'whitelisted_ips', 'Whitelisted IPs')
            }
          ]
        },
        {
          label: i18n.t('Blacklisted IP Hosts Window'),
          text: i18n.t('The window to consider when counting the amount of blacklisted IPs the endpoint has communicated with.'),
          cols: [
            {
              namespace: 'blacklisted_ip_hosts_window.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'blacklisted_ip_hosts_window.interval')
            },
            {
              namespace: 'blacklisted_ip_hosts_window.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'blacklisted_ip_hosts_window.unit')
            }
          ]
        },
        {
          label: i18n.t('Blacklisted IPs Threshold'),
          text: i18n.t('If an endpoint talks with more than this amount of blacklisted IPs in the window defined above, then it triggers an event.'),
          cols: [
            {
              namespace: 'blacklisted_ip_hosts_threshold',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'blacklisted_ip_hosts_threshold'),
              validators: validatorsFromMeta(meta, 'blacklisted_ip_hosts_threshold', 'Blacklisted IPs Threshold')
            }
          ]
        },
        {
          label: i18n.t('Blacklisted ports'),
          text: i18n.t('Which ports should be considered as vulnerable/dangerous and trigger an event. Should be a comma delimited list of ports. Also supports ranges (ex: "1000-1024" configures ports 1000 to 1024 inclusively). This list is for the outbound communication of the endpoint.'),
          cols: [
            {
              namespace: 'blacklisted_ports',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'blacklisted_ports'),
              validators: validatorsFromMeta(meta, 'blacklisted_ports', 'Blacklisted ports')
            }
          ]
        },
        {
          label: i18n.t('Blacklisted ports window'),
          text: i18n.t('The window to consider when checking for blacklisted ports communication.'),
          cols: [
            {
              namespace: 'blacklisted_ports_window.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'blacklisted_ports_window.interval')
            },
            {
              namespace: 'blacklisted_ports_window.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'blacklisted_ports_window.unit')
            }
          ]
        },
        {
          label: 'Watched Device Attributes',
          text: i18n.t('Defines the attributes that should be analysed when checking against the pristine profile of the endpoint. Leaving this empty will disable the feature.'),
          cols: [
            {
              namespace: 'watched_device_attributes',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'watched_device_attributes'),
              validators: validatorsFromMeta(meta, 'watched_device_attributes', 'Watched Device Attributes')
            }
          ]
        },
        {
          label: i18n.t('Device attributes minimal score'),
          text: i18n.t('If an endpoint doesn\'t get at least this score when being matched against the pristine profile, then it triggers an event.'),
          cols: [
            {
              namespace: 'device_attributes_diff_score',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'device_attributes_diff_score'),
              validators: validatorsFromMeta(meta, 'device_attributes_diff_score', 'Device attributes minimal score')
            }
          ]
        },
        {
         label: i18n.t('Device Attributes weight'),
         text: i18n.t('Override the weight of the different attributes when matching them against the pristine profiles. '),
         cols: [
           {
             namespace: 'device_attributes_diff_threshold_overrides',
             component: pfFormFields,
             attrs: {
               buttonLabel: i18n.t('Add field'),
               sortable: false,
               field: {
                 component: pfFieldTypeValue,
                 attrs: {
                   typeLabel: i18n.t('Select attribute'),
                   valueLabel: i18n.t('Enter weight override'),
                   fields: [
                     {
                       value: 'dhcp_fingerprint',
                       text: i18n.t('DHCP fingerprint'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'dhcp_vendor',
                       text: i18n.t('DHCP vendor'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'hostname',
                       text: i18n.t('Hostname'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'oui',
                       text: i18n.t('OUI (MAC Vendor)'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'destination_hosts',
                       text: i18n.t('Destination hosts'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'mdns_services',
                       text: i18n.t('mDNS services'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'tcp_syn_signatures',
                       text: i18n.t('TCP SYN signatures'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'tcp_syn_ack_signatures',
                       text: i18n.t('TCP SYN ACK signatures'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'upnp_server_strings',
                       text: i18n.t('UPnP server strings'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'upnp_user_agents',
                       text: i18n.t('UPnP user-agent'),
                       types: [fieldType.INTEGER],
                     },
                     {
                       value: 'user_agents',
                       text: i18n.t('HTTP user-agent'),
                       types: [fieldType.INTEGER],
                     },
                   ]
                 }
               },
               invalidFeedback: i18n.t('Inline Conditions contain one or more errors.')
             }
           }
         ]
        },
        {
          label: null,
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: `<div class="alert alert-info">
                  ${i18n.t('The default weights are:')}<br/>
                  <ul>
                    <li><strong>DHCP fingerprint</strong> = 10</li>
                    <li><strong>DHCP vendor</strong> = 10</li>
                    <li><strong>Hostname</strong> = 3</li>
                    <li><strong>OUI</strong> = 3</li>
                    <li><strong>Destination hosts</strong> = 5</li>
                    <li><strong>mDNS Services</strong> = 5</li>
                    <li><strong>TCP SYN signatures</strong> = 10</li>
                    <li><strong>TCP SYN ACK signatures</strong> = 10</li>
                    <li><strong>UPnP server strings</strong> = 5</li>
                    <li><strong>UPnP user-agents</strong> = 5</li>
                    <li><strong>HTTP user-agents</strong> = 5</li>
                  </ul>
                </div>`
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
  }
}
