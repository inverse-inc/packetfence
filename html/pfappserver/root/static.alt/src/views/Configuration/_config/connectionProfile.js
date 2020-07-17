import router from '@/router'
import store from '@/store'
import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFieldTypeMatch from '@/components/pfFieldTypeMatch'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormBooleanBuilder from '@/components/pfFormBooleanBuilder'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfTree from '@/components/pfTree'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import { pfLocalesList as localesList } from '@/globals/pfLocales'
import { pfOperators } from '@/globals/pfOperators'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasConnectionProfiles,
  connectionProfileExists,
  isMacAddress,
  isPort
} from '@/globals/pfValidators'
import {
  required,
  maxLength
} from 'vuelidate/lib/validators'

export const filters = {
  connection_sub_type: {
    value: 'connection_sub_type',
    text: i18n.t('Connection Sub Type'),
    types: [fieldType.CONNECTION_SUB_TYPE]
  },
  connection_type: {
    value: 'connection_type',
    text: i18n.t('Connection Type'),
    types: [fieldType.CONNECTION_TYPE]
  },
  network: {
    value: 'network',
    text: i18n.t('Network'),
    types: [fieldType.SUBSTRING]
  },
  node_role: {
    value: 'node_role',
    text: i18n.t('Node role'),
    types: [fieldType.ROLE_BY_NAME]
  },
  port: {
    value: 'port',
    text: i18n.t('Port'),
    types: [fieldType.INTEGER],
    validators: {
      match: {
        [i18n.t('Invalid Port Number.')]: isPort
      }
    }
  },
  realm: {
    value: 'realm',
    text: i18n.t('Realm'),
    types: [fieldType.REALM],
    taggable: true,
    tagPlaceholder: i18n.t('Click to add new Realm')
  },
  ssid: {
    value: 'ssid',
    text: i18n.t('SSID'),
    types: [fieldType.SSID],
    taggable: true,
    tagPlaceholder: i18n.t('Click to add new SSID')
  },
  switch: {
    value: 'switch',
    text: i18n.t('Switch'),
    types: [fieldType.SWITCHE]
  },
  switch_group: {
    value: 'switch_group',
    text: i18n.t('Switch Group'),
    types: [fieldType.SWITCH_GROUP]
  },
  switch_mac: {
    value: 'switch_mac',
    text: i18n.t('Switch MAC'),
    types: [fieldType.SUBSTRING],
    validators: {
      match: {
        [i18n.t('Invalid MAC address.')]: isMacAddress
      }
    }
  },
  switch_port: {
    value: 'switch_port',
    text: i18n.t('Switch Port'),
    types: [fieldType.SUBSTRING],
    validators: {
      match: {
        [i18n.t('Invalid Port Number.')]: isPort
      }
    }
  },
  tenant: {
    value: 'tenant',
    text: i18n.t('Tenant'),
    types: [fieldType.TENANT]
  },
  time: {
    value: 'time',
    text: i18n.t('Time period'),
    types: [fieldType.SUBSTRING]
  },
  uri: {
    value: 'uri',
    text: i18n.t('URI'),
    types: [fieldType.SUBSTRING]
  },
  fqdn: {
    value: 'fqdn',
    text: i18n.t('FQDN'),
    types: [fieldType.SUBSTRING]
  },
  vlan: {
    value: 'vlan',
    text: i18n.t('VLAN'),
    types: [fieldType.SUBSTRING]
  }
}

export const columns = [
  {
    key: 'status',
    label: 'Status', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'id',
    label: 'Identifier', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: 'Description', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'not_sortable',
    required: true,
    visible: false
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

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'connection_profile', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/connection_profiles',
      defaultSortKeys: [], // use natural order
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
      defaultRoute: { name: 'connection_profiles' }
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

const fieldOperatorsFromMeta = (meta = {}) => {
  const { advanced_filter: { properties: { field: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.map(allowed => {
    const { text, value, siblings: { value: { allowed_values } = {} } = {} } = allowed
    if (allowed_values) {
      return {
        text,
        value,
        options: allowed_values.sort((a, b) => {
          return a.text.localeCompare(b.text)
        })
      }
    }
    return { text, value }
  }).sort((a, b) => {
    return a.text.localeCompare(b.text)
  })
}

const valueOperatorsFromMeta = (meta = {}) => {
  const { advanced_filter: { properties: { op: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.filter(allowed => {
    const { requires = [] } = allowed
    return !requires.includes('values')
  }).map(allowed => {
    const { requires = [], value } = allowed
    return { requires, value }
  })
}

const valuesOperatorsFromMeta = (meta = {}) => {
  const { advanced_filter: { properties: { op: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.filter(allowed => {
    const { requires = [] } = allowed
    return requires.includes('values') || requires.length === 0
  }).map(allowed => {
    const { value } = allowed
    return value
  })
}

export const view = (form = {}, meta = {}) => {
  const {
    id
  } = form
  const {
    isNew = false,
    isClone = false,
    files = [],
    sortFiles = null,
    createDirectory = null,
    deleteFile = null
  } = meta

  // fields differ w/ & wo/ 'default'
  const isDefault = (id === 'default')

  return [
    {
      tab: i18n.t('Settings'),
      rows: [
        {
          label: i18n.t('Profile Name'),
          text: i18n.t('A profile id can only contain alphanumeric characters, dashes, period and or underscores.'),
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
          label: i18n.t('Profile Description'),
          cols: [
            {
              namespace: 'description',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'description')
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Enable profile'),
          cols: [
            {
              namespace: 'status',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Root Portal Module'),
          text: i18n.t('The Root Portal Module to use.'),
          cols: [
            {
              namespace: 'root_module',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'root_module')
            }
          ]
        },
        {
          label: i18n.t('Activate preregistration'),
          text: i18n.t('This activates preregistration on the connection profile. Meaning, instead of applying the access to the currently connected device, it displays a local account that is created while registering. Note that activating this disables the on-site registration on this connection profile. Also, make sure the sources on the connection profile have "Create local account" enabled.'),
          cols: [
            {
              namespace: 'preregistration',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Automatically register devices'),
          text: i18n.t('This activates automatic registation of devices for the profile. Devices will not be shown a captive portal and RADIUS authentication credentials will be used to register the device. This option only makes sense in the context of an 802.1x authentication.'),
          cols: [
            {
              namespace: 'autoregister',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Reuse dot1x credentials'),
          text: i18n.t('This option emulates SSO when someone needs to face the captive portal after a successful 802.1x connection. 802.1x credentials are reused on the portal to match an authentication and get the appropriate actions. As a security precaution, this option will only reuse 802.1x credentials if there is an authentication source matching the provided realm. This means, if users use 802.1x credentials with a domain part (username@domain, domain\\username), the domain part needs to be configured as a realm under the RADIUS section and an authentication source needs to be configured for that realm. If users do not use 802.1x credentials with a domain part, only the NULL realm will be match IF an authentication source is configured for it.'),
          cols: [
            {
              namespace: 'reuse_dot1x_credentials',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Dot1x recompute role from portal'),
          text: i18n.t('When enabled, PacketFence will not use the role initialy computed on the portal but will use the dot1x username to recompute the role.'),
          cols: [
            {
              namespace: 'dot1x_recompute_role_from_portal',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('MAC Auth recompute role from portal'),
          text: i18n.t('When enabled, PacketFence will not use the role initialy computed on the portal but will use an authorized source if defined to recompute the role.'),
          cols: [
            {
              namespace: 'mac_auth_recompute_role_from_portal',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Dot1x unset on unmatch'),
          text: i18n.t('When enabled, PacketFence will unset the role of the device if no authentication sources returned one.'),
          cols: [
            {
              namespace: 'dot1x_unset_on_unmatch',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Enable DPSK'),
          text: i18n.t('This enables the Dynamic PSK feature on this connection profile. It means that the RADIUS server will answer requests with specific attributes like the PSK key to use to connect on the SSID.'),
          cols: [
            {
              namespace: 'dpsk',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Default PSK key'),
          text: i18n.t('This is the default PSK key when you enable DPSK on this connection profile. The minimum length is eight characters.'),
          cols: [
            {
              namespace: 'default_psk_key',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'default_psk_key')
            }
          ]
        },
        {
          label: i18n.t('Automatically deregister devices on accounting stop'),
          text: i18n.t('This activates automatic deregistation of devices for the profile if PacketFence receives a RADIUS accounting stop. This option only makes sense in the context of an 802.1x authentication.'),
          cols: [
            {
              namespace: 'unreg_on_acct_stop',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('VLAN pool technique'),
          text: i18n.t('The algorithm used to calculate the VLAN in a VLAN pool.'),
          cols: [
            {
              namespace: 'vlan_pool_technique',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'vlan_pool_technique')
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Filters'),
          cols: [
            {
              namespace: 'filter_match_style',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'filter_match_style')
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Filter'),
          cols: [
            {
              namespace: 'filter',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Filter'),
                emptyText: i18n.t('With no filter specified, an advanced filter must be specified.'),
                sortable: true,
                field: {
                  component: pfFieldTypeMatch,
                  attrs: {
                    typeLabel: i18n.t('Select filter type'),
                    matchLabel: i18n.t('Select filter match'),
                    fields: [
                      filters.connection_sub_type,
                      filters.connection_type,
                      filters.network,
                      filters.node_role,
                      filters.port,
                      filters.realm,
                      filters.ssid,
                      filters.switch,
                      filters.switch_group,
                      filters.switch_mac,
                      filters.switch_port,
                      filters.tenant,
                      filters.time,
                      filters.uri,
                      filters.fqdn,
                      filters.vlan
                    ]
                  }
                },
                invalidFeedback: i18n.t('Filter(s) contain one or more errors.')
              }
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Advanced filter'),
          cols: [
            {
              namespace: 'advanced_filter',
              component: pfFormBooleanBuilder,
              attrs: {
                fieldOperators: fieldOperatorsFromMeta(meta),
                valueOperators: valueOperatorsFromMeta(meta).map(({ requires, value }) => {
                  const { [value]: text = value } = pfOperators
                  return { text, value, requires }
                }),
                valuesOperators: valuesOperatorsFromMeta(meta).map(value => {
                  const { [value]: text = value } = pfOperators
                  return { text, value }
                }),
                invalidFeedback: i18n.t('Advanced filter contains one or more errors.')
              }
            }
          ]
        },
        {
          label: i18n.t('Sources'),
          cols: [
            {
              namespace: 'sources',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Source'),
                emptyText: i18n.t('With no source specified, all internal and external sources will be used.'),
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        ...attributesFromMeta(meta, 'sources'),
                        ...{ multiple: false, closeOnSelect: true }
                      }
                    }
                  }
                },
                invalidFeedback: i18n.t('Source(s) contain one or more errors.')
              }
            }
          ]
        },
        {
          label: i18n.t('Billing Tiers'),
          cols: [
            {
              namespace: 'billing_tiers',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Billing Tier'),
                emptyText: i18n.t('With no billing tiers specified, all billing tiers will be used.'),
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        ...attributesFromMeta(meta, 'billing_tiers'),
                        ...{ multiple: false, closeOnSelect: true }
                      }
                    }
                  }
                },
                invalidFeedback: i18n.t('Billing Tier(s) contain one or more errors.')
              }
            }
          ]
        },
        {
          label: i18n.t('Provisioners'),
          cols: [
            {
              namespace: 'provisioners',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Provisioner'),
                emptyText: i18n.t('With no provisioners specified, the provisioners of the default profile will be used.'),
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        ...attributesFromMeta(meta, 'provisioners'),
                        ...{ multiple: false, closeOnSelect: true }
                      }
                    }
                  }
                },
                invalidFeedback: i18n.t('Provisioner(s) contain one or more errors.')
              }
            }
          ]
        },
        {
          label: i18n.t('Scanners'),
          cols: [
            {
              namespace: 'scans',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Scanner'),
                emptyText: i18n.t('With no scan specified, the scan engine will not be triggered.'),
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        ...attributesFromMeta(meta, 'scans'),
                        ...{ multiple: false, closeOnSelect: true }
                      }
                    }
                  }
                },
                invalidFeedback: i18n.t('Scanners(s) contain one or more errors.')
              }
            }
          ]
        },
        {
          label: i18n.t('Self service policy'),
          cols: [
            {
              namespace: 'self_service',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'self_service')
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Captive Portal'),
      rows: [
        {
          label: i18n.t('Logo'),
          cols: [
            {
              namespace: 'logo',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'logo')
            }
          ]
        },
        {
          label: i18n.t('Redirection URL'),
          text: i18n.t('Default URL to redirect to on registration/mitigation release. This is only used if a per-security event redirect URL is not defined.'),
          cols: [
            {
              namespace: 'redirecturl',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'redirecturl')
            }
          ]
        },
        {
          label: i18n.t('Force redirection URL'),
          text: i18n.t('Under most circumstances we can redirect the user to the URL he originally intended to visit. However, you may prefer to force the captive portal to redirect the user to the redirection URL.'),
          cols: [
            {
              namespace: 'always_use_redirecturl',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Block Interval'),
          text: i18n.t('The amount of time a user is blocked after reaching the defined limit for login, sms request and sms pin retry.'),
          cols: [
            {
              namespace: 'block_interval.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'block_interval.interval')
            },
            {
              namespace: 'block_interval.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'block_interval.unit')
            }
          ]
        },
        {
          label: i18n.t('SMS Pin Retry Limit'),
          text: i18n.t('Maximum number of times a user can retry a SMS PIN before having to request another PIN. A value of 0 disables the limit.'),
          cols: [
            {
              namespace: 'sms_pin_retry_limit',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'sms_pin_retry_limit')
            }
          ]
        },
        {
          label: i18n.t('SMS Request Retry Limit'),
          text: i18n.t('Maximum number of times a user can request a SMS PIN. A value of 0 disables the limit.'),
          cols: [
            {
              namespace: 'sms_request_limit',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'sms_request_limit')
            }
          ]
        },
        {
          label: i18n.t('Login Attempt Limit'),
          text: i18n.t('Limit the number of login attempts. A value of 0 disables the limit.'),
          cols: [
            {
              namespace: 'login_attempt_limit',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'login_attempt_limit')
            }
          ]
        },
        {
          label: i18n.t('Allow access to registration portal when registered'),
          text: i18n.t('This allows already registered users to be able to re-register their device by first accessing the status page and then accessing the portal. This is useful to allow users to extend their access even though they are already registered.'),
          cols: [
            {
              namespace: 'access_registration_when_registered',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Network Logoff'),
          text: i18n.t('This allows users to access the network logoff page (http://{fqdn}/networklogoff) in order to terminate their network access (switch their device back to unregistered).', store.getters['$_bases/general']),
          cols: [
            {
              namespace: 'network_logoff',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Network Logoff Popup'),
          text: i18n.t('When the "Network Logoff" feature is enabled, this will have it opened in a popup at the end of the registration process.'),
          cols: [
            {
              namespace: 'network_logoff_popup',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Languages'),
          cols: [
            {
              namespace: 'locale',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Locale'),
                emptyText: i18n.t('With no language specified, all supported locales will be available.'),
                maxFields: localesList.length,
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        collapseObject: true,
                        placeholder: i18n.t('Click to select a locale'),
                        trackBy: 'value',
                        label: 'text',
                        options: localesList
                      }
                    }
                  }
                },
                invalidFeedback: i18n.t('Locale(s) contain one or more errors.')
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Files'),
      disabled: isNew,
      rows: [
        {
          cols: [
            {
              namespace: 'files',
              component: pfTree,
              attrs: {
                path: '',
                items: files,
                fields: [
                  {
                    key: 'name',
                    label: 'Name', // i18n defer
                    class: 'w-50',
                    required: true,
                    sortable: true
                  },
                  {
                    key: 'size',
                    label: 'Size', // i18n defer
                    formatter: formatter.fileSize,
                    tdClass: 'text-right',
                    sortable: true
                  },
                  {
                    key: 'mtime',
                    label: 'Last modification', // i18n defer
                    formatter: formatter.shortDateTime,
                    tdClass: 'text-right',
                    sortable: true
                  },
                  {
                    key: 'buttons',
                    label: '',
                    locked: true
                  }
                ],
                isLoadingStoreGetters: ['$_connection_profiles/isLoading', '$_connection_profiles/isLoadingFiles'],
                previewPath: (item) => {
                  let path = ['/config/profile', id, 'preview']
                  if (item.path) path.push(item.path)
                  path.push(item.name)
                  return path.join('/')
                },
                childrenKey: 'entries',
                childrenIf: (item) => item.type === 'dir' && 'entries' in item,
                sortBy: 'name',
                onSortingChanged: sortFiles,
                onNodeClick: (item) => router.push({ name: 'connectionProfileFile', params: { id, filename: item.path ? [item.path, item.name].join('/') : item.name } }),
                onNodeCreate: (path) => router.push({ name: 'newConnectionProfileFile', params: { id, path } }),
                onNodeDelete: deleteFile,
                onContainerDelete: deleteFile,
                onContainerCreate: createDirectory
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
    id,
    filter = [],
    advanced_filter,
    sources = [],
    billing_tiers = [],
    provisioners = [],
    scans = [],
    locale = []
  } = form
  const {
    isNew = false,
    isClone = false
  } = meta

  // fields differ w/ & wo/ 'default'
  const isDefault = (id === 'default')

  const requiresFieldsAssociated = valueOperatorsFromMeta(meta).reduce((associated, item) => {
      const { value, requires } = item
      associated[value] = requires
      return associated
    }, {})

  const advancedFilterValidator = (meta = {}, advanced_filter = {}, level = 0) => {
    const { op, values } = advanced_filter
    if (values && values.constructor === Array) { // op
      return {
        op: {
          ...{
            [i18n.t('Operator required.')]: required
          },
          ...((level > 0) // require 2 values when not @ root condition
            ? {
              [i18n.t('Minimum 2 values required.')]: conditional(values.length >= 2)
            }
            : {}
          )
        },
        values: {
          ...(values || []).map(value => advancedFilterValidator(meta, value, ++level))
        }
      }
    } else { // value
      const { [op]: requires = [] } = requiresFieldsAssociated
      const showField = (!op || requires.includes('field'))
      const showValue = (!op || requires.includes('value'))
      return {
        field: {
          ...((showField)
            ? { [i18n.t('Field required.')]: required }
            : {}
          )
        },
        op: {
          [i18n.t('Operator required.')]: required
        },
        value: {
          ...((showValue)
            ? { [i18n.t('Value required.')]: required }
            : {}
          )
        }
      }
    }
  }

  return {
    ...((isDefault)
      ? {} // isDefault
      : { // !isDefault
        filter: {
          ...{
            [i18n.t('Filter or advanced filter required.')]: not(and(conditional(!filter || filter.length === 0), conditional(!advanced_filter)))
          },
          ...(filter || []).map(_filter => { // index based filter validators
            if (_filter) {
              const { type } = _filter
              if (type) {
                const { [type]: { validators: { match: matchValidators = {} } = {} } = {} } = filters
                if (validators) {
                  return {
                    match: {
                      ...{
                        [i18n.t('Match required.')]: required,
                        [i18n.t('Maximum 255 characters.')]: maxLength(255)
                      },
                      ...matchValidators
                    }
                  }
                }
              }
            }
            return {
              type: {
                [i18n.t('Type required.')]: required
              }
            }
          })
        },
        advanced_filter: advancedFilterValidator(meta, advanced_filter)
      }
    ),
    ...{
      id: {
        ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
        ...{
          [i18n.t('Connection Profile exists.')]: not(and(required, conditional(isNew || isClone), hasConnectionProfiles, connectionProfileExists))
        }
      },
      description: validatorsFromMeta(meta, 'description', i18n.t('Description')),
      root_module: validatorsFromMeta(meta, 'root_module', i18n.t('Module')),
      default_psk_key: validatorsFromMeta(meta, 'default_psk_key', i18n.t('Key')),
      vlan_pool_technique: validatorsFromMeta(meta, 'vlan_pool_technique', i18n.t('Algorithm')),
      filter_match_style: validatorsFromMeta(meta, 'filter_match_style', i18n.t('Filters')),
      sources: {
        ...validatorsFromMeta(meta, 'sources', i18n.t('Sources')),
        ...{
          $each: {
            [i18n.t('Source required.')]: required,
            [i18n.t('Duplicate source.')]: conditional((value) => sources.filter(v => v === value).length <= 1)
          }
        }
      },
      billing_tiers: {
        ...validatorsFromMeta(meta, 'billing_tiers', i18n.t('Billing tier')),
        ...{
          $each: {
            [i18n.t('Billing tier required.')]: required,
            [i18n.t('Duplicate billing tier.')]: conditional((value) => billing_tiers.filter(v => v === value).length <= 1)
          }
        }
      },
      provisioners: {
        ...validatorsFromMeta(meta, 'provisioners', i18n.t('Provisioner')),
        ...{
          $each: {
            [i18n.t('Provisioner required.')]: required,
            [i18n.t('Duplicate provisioner.')]: conditional((value) => provisioners.filter(v => v === value).length <= 1)
          }
        }
      },
      scans: {
        ...validatorsFromMeta(meta, 'scans', i18n.t('Scans')),
        ...{
          $each: {
            [i18n.t('Scan required.')]: required,
            [i18n.t('Duplicate scan.')]: conditional((value) => scans.filter(v => v === value).length <= 1)
          }
        }
      },
      self_service: validatorsFromMeta(meta, 'self_service', i18n.t('Registration')),
      logo: validatorsFromMeta(meta, 'logo', i18n.t('Logo')),
      redirecturl: validatorsFromMeta(meta, 'redirecturl', i18n.t('Redirect')),
      block_interval: {
        interval: validatorsFromMeta(meta, 'block_interval.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'block_interval.unit', i18n.t('Unit'))
      },
      sms_pin_retry_limit: validatorsFromMeta(meta, 'sms_pin_retry_limit', i18n.t('Limit')),
      sms_request_limit: validatorsFromMeta(meta, 'sms_request_limit', i18n.t('Limit')),
      login_attempt_limit: validatorsFromMeta(meta, 'login_attempt_limit', i18n.t('Limit')),
      locale: {
        $each: {
          [i18n.t('Locale required.')]: required,
          [i18n.t('Duplicate locale.')]: conditional((value) => locale.filter(v => v === value).length <= 1)
        }
      }
    }
  }
}
