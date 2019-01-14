import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFieldTypeMatch from '@/components/pfFieldTypeMatch'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import { pfFieldType as fieldType } from '@/globals/pfField'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields,
  pfConfigurationViewFields,
  pfConfigurationLocales
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  not,
  conditional,
  connectionProfileExists,
  isPort,
  limitSiblingFields
} from '@/globals/pfValidators'

const {
  required,
  alphaNum,
  integer,
  macAddress,
  maxLength,
  minLength
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
        [i18n.t('Invalid MAC Address.')]: macAddress
      }
    }
  },
  switch_port: {
    value: 'switch_port',
    text: i18n.t('Switch Port'),
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
  pfConfigurationListColumns.status,
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Identifier') }), // re-label
  pfConfigurationListColumns.description,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationConnectionProfilesListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Identifier') }), // re-text
  pfConfigurationListFields.description
]

export const pfConfigurationConnectionProfileViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    connectionProfile = {},
    sources = [],
    billingTiers = [],
    provisionings = [],
    scans = [],
    general = {}
  } = context

  // fields differ w/ & wo/ 'default'
  const isDefault = (connectionProfile.id === 'default')

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
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Name required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Alphanumeric characters only.')]: alphaNum,
                [i18n.t('Connection Profile exists.')]: not(and(required, conditional(isNew || isClone), connectionProfileExists))
              }
            }
          ]
        },
        Object.assign(pfConfigurationViewFields.description, { label: i18n.t('Profile Description') }), // re-label
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
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to select'),
                trackBy: 'value',
                label: 'text',
                options: [
                  {
                    text: i18n.t('Default portal policy'),
                    value: 'default_policy'
                  },
                  {
                    text: i18n.t('Default pending policy'),
                    value: 'default_pending_policy'
                  }
                ]
              },
              validators: {
                [i18n.t('Role required.')]: required
              }
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
              validators: {
                [i18n.t('Minimum 8 characters.')]: minLength(8),
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
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
          if: !isDefault,
          label: i18n.t('Filters'),
          fields: [
            {
              key: 'filter_match_style',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to select a match style'),
                trackBy: 'value',
                label: 'text',
                allowEmpty: false,
                clearOnSelect: false,
                options: [
                  { text: i18n.t('If ALL of the following conditions are met:'), value: 'all' },
                  { text: i18n.t('If ANY of the following conditions are met:'), value: 'any' }
                ]
              },
              validators: {
                [i18n.t('Filter or advanced filter required.')]: conditional((value) => {
                  return ( // false on error, true on success
                    isDefault ||
                    (!!value) ||
                    ('filter' in connectionProfile && connectionProfile.filter.length > 0) ||
                    ('advanced_filter' in connectionProfile && !!connectionProfile.advanced_filter)
                  )
                })
              }
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
                      pfConfigurationConnectionProfileFilters.vlan
                    ]
                  }
                },
                invalidFeedback: [
                  { [i18n.t('Filter(s) contain one or more errors.')]: true }
                ]
              },
              validators: {
                [i18n.t('Filter or advanced filter required.')]: conditional((value) => {
                  return ( // false on error, true on success
                    isDefault ||
                    (typeof value !== 'undefined' && value.length > 0) ||
                    ('advanced_filter' in connectionProfile && !!connectionProfile.advanced_filter)
                  )
                })
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
                rows: 3
              },
              validators: {
                [i18n.t('Filter or advanced filter required.')]: conditional((value) => {
                  return ( // false on error, true on success
                    isDefault ||
                    (!!value) ||
                    ('filter' in connectionProfile && connectionProfile.filter.length > 0)
                  )
                }),
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
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
                maxFields: sources.length,
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        collapseObject: true,
                        placeholder: i18n.t('Click to select a source'),
                        trackBy: 'value',
                        label: 'text',
                        options: sources.map(source => {
                          return { text: `${source.id} (${source.type} - ${source.description})`, value: source.id }
                        })
                      },
                      validators: {
                        [i18n.t('Source required.')]: required,
                        [i18n.t('Duplicate Source.')]: conditional((value) => {
                          return !(connectionProfile.sources.filter(v => v === value).length > 1)
                        })
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
                maxFields: billingTiers.length,
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        collapseObject: true,
                        placeholder: i18n.t('Click to select a billing tier'),
                        trackBy: 'value',
                        label: 'text',
                        options: billingTiers.map(billingTier => {
                          return { text: `${billingTier.id} (${billingTier.name} - ${billingTier.description})`, value: billingTier.id }
                        })
                      },
                      validators: {
                        [i18n.t('Billing Tier required.')]: required,
                        [i18n.t('Duplicate Billing Tier.')]: conditional((value) => {
                          if (connectionProfile.billingTiers === Array) {
                            return !(connectionProfile.billingTiers.filter(v => v === value).length > 1)
                          }
                          return true
                        })
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
                maxFields: provisionings.length,
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        collapseObject: true,
                        placeholder: i18n.t('Click to select a provisioner'),
                        trackBy: 'value',
                        label: 'text',
                        options: provisionings.map(provisioning => {
                          return { text: `${provisioning.id} (${provisioning.type} - ${provisioning.description})`, value: provisioning.id }
                        })
                      },
                      validators: {
                        [i18n.t('Provisioner required.')]: required,
                        [i18n.t('Duplicate Provisioner.')]: conditional((value) => {
                          if (connectionProfile.provisioners === Array) {
                            return !(connectionProfile.provisioners.filter(v => v === value).length > 1)
                          }
                          return true
                        })
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
                maxFields: scans.length,
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        collapseObject: true,
                        placeholder: i18n.t('Click to select a scanner'),
                        trackBy: 'value',
                        label: 'text',
                        options: scans.map(scan => {
                          return { text: `${scan.id} (${scan.type} - ${scan.description})`, value: scan.id }
                        })
                      },
                      validators: {
                        [i18n.t('Scanner required.')]: required,
                        [i18n.t('Duplicate Scanner.')]: conditional((value) => {
                          if (connectionProfile.provisioners === Array) {
                            return !(connectionProfile.provisioners.filter(v => v === value).length > 1)
                          }
                          return true
                        })
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
          label: i18n.t('Device registration'),
          fields: [
            {
              key: 'device_registration',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to select'),
                trackBy: 'value',
                label: 'text',
                options: [
                  {
                    text: i18n.t('default'),
                    value: 'default'
                  }
                ]
              }
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
              validators: {
                [i18n.t('Logo required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Redirection URL'),
          text: i18n.t('Default URL to redirect to on registration/mitigation release. This is only used if a per-violation redirect URL is not defined.'),
          fields: [
            {
              key: 'redirecturl',
              component: pfFormInput,
              validators: {
                [i18n.t('URL required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
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
              attrs: {
                type: 'number'
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Integer values required.')]: integer
              }
            },
            {
              key: 'block_interval.unit',
              component: pfFormSelect,
              attrs: {
                options: [
                  { value: 's', text: i18n.t('seconds') },
                  { value: 'm', text: i18n.t('minutes') },
                  { value: 'h', text: i18n.t('hours') },
                  { value: 'D', text: i18n.t('days') },
                  { value: 'W', text: i18n.t('weeks') },
                  { value: 'M', text: i18n.t('months') },
                  { value: 'Y', text: i18n.t('years') }
                ]
              }
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
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Integer values required.')]: integer
              }
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
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Integer values required.')]: integer
              }
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
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Integer values required.')]: integer
              }
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
                          return !(connectionProfile.locale.filter(v => v === value).length > 1)
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
      disabled: true,
      fields: []
    }
  ]
}

export const pfConfigurationConnectionProfileViewDefaults = (context = {}) => {
  return {
    id: null,
    status: 'enabled',
    root_module: 'default_policy',
    dot1x_recompute_role_from_portal: 'enabled',
    filter_match_style: 'any',
    block_interval: {
      interval: 10,
      unit: 'm'
    },
    sms_pin_retry_limit: 0,
    sms_request_limit: 0,
    login_attempt_limit: 0
  }
}
