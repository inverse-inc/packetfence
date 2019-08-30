import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFieldTypeMatch from '@/components/pfFieldTypeMatch'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import pfTree from '@/components/pfTree'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta,
  pfConfigurationLocales
} from '@/globals/configuration/pfConfiguration'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasConnectionProfiles,
  connectionProfileExists,
  isMacAddress,
  isPort,
  limitSiblingFields
} from '@/globals/pfValidators'

const {
  required,
  maxLength
} = require('vuelidate/lib/validators')

export const pfConfigurationConnectionProfileFilters = {
  connection_sub_type: {
    value: 'connection_sub_type',
    text: i18n.t('Connection Sub Type'),
    types: [fieldType.CONNECTION_SUB_TYPE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required
      }
    }
  },
  connection_type: {
    value: 'connection_type',
    text: i18n.t('Connection Type'),
    types: [fieldType.CONNECTION_TYPE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required
      }
    }
  },
  network: {
    value: 'network',
    text: i18n.t('Network'),
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  node_role: {
    value: 'node_role',
    text: i18n.t('Node role'),
    types: [fieldType.ROLE_BY_NAME],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required
      }
    }
  },
  port: {
    value: 'port',
    text: i18n.t('Port'),
    types: [fieldType.INTEGER],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Invalid Port Number.')]: isPort
      }
    }
  },
  realm: {
    value: 'realm',
    text: i18n.t('Realm'),
    types: [fieldType.REALM],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  ssid: {
    value: 'ssid',
    text: i18n.t('SSID'),
    types: [fieldType.SSID],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  switch: {
    value: 'switch',
    text: i18n.t('Switch'),
    types: [fieldType.SWITCHE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  switch_group: {
    value: 'switch_group',
    text: i18n.t('Switch Group'),
    types: [fieldType.SWITCH_GROUP],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required
      }
    }
  },
  switch_mac: {
    value: 'switch_mac',
    text: i18n.t('Switch MAC'),
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Invalid MAC address.')]: isMacAddress
      }
    }
  },
  switch_port: {
    value: 'switch_port',
    text: i18n.t('Switch Port'),
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  tenant: {
    value: 'tenant',
    text: i18n.t('Tenant'),
    types: [fieldType.TENANT],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  time: {
    value: 'time',
    text: i18n.t('Time period'),
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  uri: {
    value: 'uri',
    text: i18n.t('URI'),
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  fqdn: {
    value: 'fqdn',
    text: i18n.t('FQDN'),
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  vlan: {
    value: 'vlan',
    text: i18n.t('VLAN'),
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate filter.')]: limitSiblingFields(['type', 'match'])
      },
      match: {
        [i18n.t('Match required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  }
}

export const pfConfigurationConnectionProfilesListColumns = [
  {
    key: 'status',
    label: i18n.t('Status'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'id',
    label: i18n.t('Identifier'),
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

export const pfConfigurationConnectionProfilesListFields = [
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

export const pfConfigurationConnectionProfileListConfig = (context = {}) => {
  const { $i18n } = context
  return {
    columns: pfConfigurationConnectionProfilesListColumns,
    fields: pfConfigurationConnectionProfilesListFields,
    rowClickRoute (item, index) {
      return { name: 'connection_profile', params: { id: item.id } }
    },
    searchPlaceholder: $i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/connection_profiles',
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

export const pfConfigurationConnectionProfileViewFields = (context = {}) => {
  const {
    $router = {},
    isNew = false,
    isClone = false,
    storeName = null,
    form = {},
    files = [],
    sortFiles = null,
    options: {
      meta = {}
    },
    general = {},
    createDirectory = null,
    deleteFile = null
  } = context

  // fields differ w/ & wo/ 'default'
  const isDefault = (form.id === 'default')

  return [
    {
      tab: i18n.t('Settings'),
      fields: [
        {
          label: i18n.t('Profile Name'),
          text: i18n.t('A profile id can only contain alphanumeric characters, dashes, period and or underscores.'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'id', i18n.t('Name')),
                ...{
                  [i18n.t('Connection Profile exists.')]: not(and(required, conditional(isNew || isClone), hasConnectionProfiles, connectionProfileExists))
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Profile Description'),
          fields: [
            {
              key: 'description',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'description'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'description', i18n.t('Description'))
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Enable profile'),
          fields: [
            {
              key: 'status',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Root Portal Module'),
          text: i18n.t('The Root Portal Module to use.'),
          fields: [
            {
              key: 'root_module',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'root_module'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'root_module', i18n.t('Module'))
            }
          ]
        },
        {
          label: i18n.t('Activate preregistration'),
          text: i18n.t('This activates preregistration on the connection profile. Meaning, instead of applying the access to the currently connected device, it displays a local account that is created while registering. Note that activating this disables the on-site registration on this connection profile. Also, make sure the sources on the connection profile have "Create local account" enabled.'),
          fields: [
            {
              key: 'preregistration',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Automatically register devices'),
          text: i18n.t('This activates automatic registation of devices for the profile. Devices will not be shown a captive portal and RADIUS authentication credentials will be used to register the device. This option only makes sense in the context of an 802.1x authentication.'),
          fields: [
            {
              key: 'autoregister',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Reuse dot1x credentials'),
          text: i18n.t('This option emulates SSO when someone needs to face the captive portal after a successful 802.1x connection. 802.1x credentials are reused on the portal to match an authentication and get the appropriate actions. As a security precaution, this option will only reuse 802.1x credentials if there is an authentication source matching the provided realm. This means, if users use 802.1x credentials with a domain part (username@domain, domain\\username), the domain part needs to be configured as a realm under the RADIUS section and an authentication source needs to be configured for that realm. If users do not use 802.1x credentials with a domain part, only the NULL realm will be match IF an authentication source is configured for it.'),
          fields: [
            {
              key: 'reuse_dot1x_credentials',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Dot1x recompute role from portal'),
          text: i18n.t('When enabled, PacketFence will not use the role initialy computed on the portal but will use the dot1x username to recompute the role.'),
          fields: [
            {
              key: 'dot1x_recompute_role_from_portal',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Dot1x unset on unmatch'),
          text: i18n.t('When enabled, PacketFence will unset the role of the device if no authentication sources returned one.'),
          fields: [
            {
              key: 'dot1x_unset_on_unmatch',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Enable DPSK'),
          text: i18n.t('This enables the Dynamic PSK feature on this connection profile. It means that the RADIUS server will answer requests with specific attributes like the PSK key to use to connect on the SSID.'),
          fields: [
            {
              key: 'dpsk',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Default PSK key'),
          text: i18n.t('This is the default PSK key when you enable DPSK on this connection profile. The minimum length is eight characters.'),
          fields: [
            {
              key: 'default_psk_key',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'default_psk_key'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'default_psk_key', i18n.t('Key'))
            }
          ]
        },
        {
          label: i18n.t('Automatically deregister devices on accounting stop'),
          text: i18n.t('This activates automatic deregistation of devices for the profile if PacketFence receives a RADIUS accounting stop.'),
          fields: [
            {
              key: 'unreg_on_acct_stop',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('VLAN pool technique'),
          text: i18n.t('The algorithm used to calculate the VLAN in a VLAN pool.'),
          fields: [
            {
              key: 'vlan_pool_technique',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'vlan_pool_technique'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'vlan_pool_technique', i18n.t('Algorithm'))
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Filters'),
          fields: [
            {
              key: 'filter_match_style',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'filter_match_style'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'filter_match_style', i18n.t('Filters'))
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Filter'),
          fields: [
            {
              key: 'filter',
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
                      pfConfigurationConnectionProfileFilters.connection_sub_type,
                      pfConfigurationConnectionProfileFilters.connection_type,
                      pfConfigurationConnectionProfileFilters.network,
                      pfConfigurationConnectionProfileFilters.node_role,
                      pfConfigurationConnectionProfileFilters.port,
                      pfConfigurationConnectionProfileFilters.realm,
                      pfConfigurationConnectionProfileFilters.ssid,
                      pfConfigurationConnectionProfileFilters.switch,
                      pfConfigurationConnectionProfileFilters.switch_group,
                      pfConfigurationConnectionProfileFilters.switch_mac,
                      pfConfigurationConnectionProfileFilters.switch_port,
                      pfConfigurationConnectionProfileFilters.tenant,
                      pfConfigurationConnectionProfileFilters.time,
                      pfConfigurationConnectionProfileFilters.uri,
                      pfConfigurationConnectionProfileFilters.fqdn,
                      pfConfigurationConnectionProfileFilters.vlan
                    ]
                  }
                },
                invalidFeedback: [
                  { [i18n.t('Filter(s) contain one or more errors.')]: true }
                ]
              },
              validators: {
                [i18n.t('Filter or advanced filter required.')]: not(and(conditional(!form.filter), conditional(!form.advanced_filter)))
              }
            }
          ]
        },
        {
          if: !isDefault,
          label: i18n.t('Advanced filter'),
          fields: [
            {
              key: 'advanced_filter',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'advanced_filter'),
                ...{
                  rows: 3
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'advanced_filter', i18n.t('Filter')),
                ...{
                  [i18n.t('Filter or advanced filter required.')]: not(and(conditional(!form.filter), conditional(!form.advanced_filter)))
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Sources'),
          fields: [
            {
              key: 'sources',
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
                        ...pfConfigurationAttributesFromMeta(meta, 'sources'),
                        ...{ multiple: false, closeOnSelect: true }
                      },
                      validators: {
                        ...pfConfigurationValidatorsFromMeta(meta, 'sources', i18n.t('Sources')),
                        ...{
                          [i18n.t('Duplicate source.')]: conditional((value) => {
                            return !(form.sources.filter(v => v === value).length > 1)
                          })
                        }
                      }
                    }
                  }
                },
                invalidFeedback: [
                  { [i18n.t('Source(s) contain one or more errors.')]: true }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Billing Tiers'),
          fields: [
            {
              key: 'billing_tiers',
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
                        ...pfConfigurationAttributesFromMeta(meta, 'billing_tiers'),
                        ...{ multiple: false, closeOnSelect: true }
                      },
                      validators: {
                        ...pfConfigurationValidatorsFromMeta(meta, 'billing_tiers', i18n.t('Billing tier')),
                        ...{
                          [i18n.t('Duplicate billing tier.')]: conditional((value) => {
                            return !(form.billing_tiers.filter(v => v === value).length > 1)
                          })
                        }
                      }
                    }
                  }
                },
                invalidFeedback: [
                  { [i18n.t('Billing Tier(s) contain one or more errors.')]: true }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Provisioners'),
          fields: [
            {
              key: 'provisioners',
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
                        ...pfConfigurationAttributesFromMeta(meta, 'provisioners'),
                        ...{ multiple: false, closeOnSelect: true }
                      },
                      validators: {
                        ...pfConfigurationValidatorsFromMeta(meta, 'provisioners', i18n.t('Provisioner')),
                        ...{
                          [i18n.t('Duplicate provisioner.')]: conditional((value) => {
                            return !(form.provisioners.filter(v => v === value).length > 1)
                          })
                        }
                      }
                    }
                  }
                },
                invalidFeedback: [
                  { [i18n.t('Provisioner(s) contain one or more errors.')]: true }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Scanners'),
          fields: [
            {
              key: 'scans',
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
                        ...pfConfigurationAttributesFromMeta(meta, 'scans'),
                        ...{ multiple: false, closeOnSelect: true }
                      },
                      validators: {
                        ...pfConfigurationValidatorsFromMeta(meta, 'scans', i18n.t('Scans')),
                        ...{
                          [i18n.t('Duplicate scan.')]: conditional((value) => {
                            return !(form.scans.filter(v => v === value).length > 1)
                          })
                        }
                      }
                    }
                  }
                },
                invalidFeedback: [
                  { [i18n.t('Scanners(s) contain one or more errors.')]: true }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Self service policy'),
          fields: [
            {
              key: 'self_service',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'self_service'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'self_service', i18n.t('Registration'))
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Captive Portal'),
      fields: [
        {
          label: i18n.t('Logo'),
          fields: [
            {
              key: 'logo',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'logo'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'logo', i18n.t('Logo'))
            }
          ]
        },
        {
          label: i18n.t('Redirection URL'),
          text: i18n.t('Default URL to redirect to on registration/mitigation release. This is only used if a per-security event redirect URL is not defined.'),
          fields: [
            {
              key: 'redirecturl',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'redirecturl'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'redirecturl', i18n.t('Redirect'))
            }
          ]
        },
        {
          label: i18n.t('Force redirection URL'),
          text: i18n.t('Under most circumstances we can redirect the user to the URL he originally intended to visit. However, you may prefer to force the captive portal to redirect the user to the redirection URL.'),
          fields: [
            {
              key: 'always_use_redirecturl',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Block Interval'),
          text: i18n.t('The amount of time a user is blocked after reaching the defined limit for login, sms request and sms pin retry.'),
          fields: [
            {
              key: 'block_interval.interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'block_interval.interval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'block_interval.interval', i18n.t('Interval'))
            },
            {
              key: 'block_interval.unit',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'block_interval.unit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'block_interval.unit', i18n.t('Unit'))
            }
          ]
        },
        {
          label: i18n.t('SMS Pin Retry Limit'),
          text: i18n.t('Maximum number of times a user can retry a SMS PIN before having to request another PIN. A value of 0 disables the limit.'),
          fields: [
            {
              key: 'sms_pin_retry_limit',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'sms_pin_retry_limit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'sms_pin_retry_limit', i18n.t('Limit'))
            }
          ]
        },
        {
          label: i18n.t('SMS Request Retry Limit'),
          text: i18n.t('Maximum number of times a user can request a SMS PIN. A value of 0 disables the limit.'),
          fields: [
            {
              key: 'sms_request_limit',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'sms_request_limit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'sms_request_limit', i18n.t('Limit'))
            }
          ]
        },
        {
          label: i18n.t('Login Attempt Limit'),
          text: i18n.t('Limit the number of login attempts. A value of 0 disables the limit.'),
          fields: [
            {
              key: 'login_attempt_limit',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'login_attempt_limit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'login_attempt_limit', i18n.t('Limit'))
            }
          ]
        },
        {
          label: i18n.t('Allow access to registration portal when registered'),
          text: i18n.t('This allows already registered users to be able to re-register their device by first accessing the status page and then accessing the portal. This is useful to allow users to extend their access even though they are already registered.'),
          fields: [
            {
              key: 'access_registration_when_registered',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Network Logoff'),
          text: i18n.t('This allows users to access the network logoff page (http://{fqdn}/networklogoff) in order to terminate their network access (switch their device back to unregistered).', general),
          fields: [
            {
              key: 'network_logoff',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Network Logoff Popup'),
          text: i18n.t('When the "Network Logoff" feature is enabled, this will have it opened in a popup at the end of the registration process.'),
          fields: [
            {
              key: 'network_logoff_popup',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Languages'),
          fields: [
            {
              key: 'locale',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Locale'),
                emptyText: i18n.t('With no language specified, all supported locales will be available.'),
                maxFields: pfConfigurationLocales.length,
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
                        options: pfConfigurationLocales
                      },
                      validators: {
                        [i18n.t('Locale required.')]: required,
                        [i18n.t('Duplicate locale.')]: conditional((value) => {
                          return !(form.locale.filter(v => v === value).length > 1)
                        })
                      }
                    }
                  }
                },
                invalidFeedback: [
                  { [i18n.t('Locale(s) contain one or more errors.')]: true }
                ]
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Files'),
      disabled: isNew,
      fields: [
        {
          fields: [
            {
              key: 'files',
              component: pfTree,
              attrs: {
                path: '',
                items: files,
                fields: [
                  {
                    key: 'name',
                    label: i18n.t('Name'),
                    class: 'w-50',
                    required: true,
                    sortable: true
                  },
                  {
                    key: 'size',
                    label: i18n.t('Size'),
                    formatter: formatter.fileSize,
                    class: 'text-right',
                    sortable: true
                  },
                  {
                    key: 'mtime',
                    label: i18n.t('Last modification'),
                    formatter: formatter.shortDateTime,
                    class: 'text-right',
                    sortable: true
                  },
                  {
                    key: 'buttons',
                    label: '',
                    locked: true
                  }
                ],
                isLoadingStoreGetters: [[storeName, 'isLoading'].join('/'), [storeName, 'isLoadingFiles'].join('/')],
                previewPath: (item) => {
                  let path = ['/config/profile', form.id, 'preview']
                  if (item.path) path.push(item.path)
                  path.push(item.name)
                  return path.join('/')
                },
                childrenKey: 'entries',
                childrenIf: (item) => item.type === 'dir' && 'entries' in item,
                sortBy: 'name',
                onSortingChanged: sortFiles,
                onNodeClick: (item) => $router.push({ name: 'connectionProfileFile', params: { id: form.id, filename: item.path ? [item.path, item.name].join('/') : item.name } }),
                onNodeCreate: (path) => $router.push({ name: 'newConnectionProfileFile', params: { id: form.id, path } }),
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
