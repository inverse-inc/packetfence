import i18n from '@/utils/locale'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import {
  and,
  not,
  conditional,
  isFQDN,
  isPort,
  sourceExists
} from '@/globals/pfValidators'
const {
  required,
  alphaNum,
  integer,
  macAddress,
  ipAddress
} = require('vuelidate/lib/validators')

export const pfConfigurationListColumns = {
  admin_strip_username: {
    key: 'admin_strip_username',
    label: i18n.t('Strip Admin'),
    sortable: true,
    visible: true
  },
  class: {
    key: 'class',
    label: i18n.t('Class'),
    sortable: true,
    visible: true
  },
  description: {
    key: 'description',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  id: {
    key: 'id',
    label: i18n.t('Name'),
    sortable: true,
    visible: true
  },
  ip: {
    key: 'ip',
    label: i18n.t('IP Address'),
    sortable: true,
    visible: true
  },
  max_nodes_per_pid: {
    key: 'max_nodes_per_pid',
    label: i18n.t('Max nodes per user'),
    sortable: true,
    visible: true
  },
  notes: {
    key: 'notes',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  portal_strip_username: {
    key: 'portal_strip_username',
    label: i18n.t('Strip Portal'),
    sortable: true,
    visible: true
  },
  pvid: {
    key: 'pvid',
    label: i18n.t('Native VLAN'),
    sortable: true,
    visible: true
  },
  radius_strip_username: {
    key: 'radius_strip_username',
    label: i18n.t('Strip RADIUS'),
    sortable: true,
    visible: true
  },
  taggedVlan: {
    key: 'taggedVlan',
    label: i18n.t('Tagged VLAN\'s'),
    sortable: false,
    visible: true
  },
  trunkPort: {
    key: 'trunkPort',
    label: i18n.t('Trunk Port'),
    sortable: true,
    visible: true
  },
  type: {
    key: 'type',
    label: i18n.t('Type'),
    sortable: true,
    visible: true
  },
  workgroup: {
    key: 'workgroup',
    label: i18n.t('Workgroup'),
    sortable: true,
    visible: true
  },
  /* Special columns not mapped to any real configuration */
  buttons: {
    key: 'buttons',
    label: '',
    sortable: false,
    visible: true,
    locked: true
  }
}

export const pfConfigurationAuthenticationSourcesListColumns = [
  pfConfigurationListColumns.id,
  pfConfigurationListColumns.description,
  pfConfigurationListColumns.class,
  pfConfigurationListColumns.type,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationDomainsListColumns = [
  pfConfigurationListColumns.id,
  pfConfigurationListColumns.workgroup
]

export const pfConfigurationFloatingDevicesListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('MAC') }), // re-label
  pfConfigurationListColumns.ip,
  pfConfigurationListColumns.pvid,
  pfConfigurationListColumns.taggedVlan,
  pfConfigurationListColumns.trunkPort
]

export const pfConfigurationRealmsListColumns = [
  pfConfigurationListColumns.id,
  pfConfigurationListColumns.portal_strip_username,
  pfConfigurationListColumns.admin_strip_username,
  pfConfigurationListColumns.radius_strip_username
]

export const pfConfigurationRolesListColumns = [
  pfConfigurationListColumns.id,
  pfConfigurationListColumns.notes,
  pfConfigurationListColumns.max_nodes_per_pid,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationListFields = {
  id: {
    value: 'id',
    text: i18n.t('Name'),
    types: [conditionType.SUBSTRING]
  },
  class: {
    value: 'class',
    text: i18n.t('Class'),
    types: [conditionType.SUBSTRING]
  },
  description: {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  },
  ip: {
    value: 'ip',
    text: i18n.t('IP Address'),
    types: [conditionType.SUBSTRING]
  },
  notes: {
    value: 'notes',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  },
  type: {
    value: 'type',
    text: i18n.t('Type'),
    types: [conditionType.SUBSTRING]
  },
  workgroup: {
    value: 'workgroup',
    text: i18n.t('Workgroup'),
    types: [conditionType.SUBSTRING]
  }
}

export const pfConfigurationAuthenticationSourcesListFields = [
  pfConfigurationListFields.id,
  pfConfigurationListFields.description,
  pfConfigurationListFields.class,
  pfConfigurationListFields.type
]

export const pfConfigurationDomainsListFields = [
  pfConfigurationListFields.id,
  pfConfigurationListFields.workgroup
]

export const pfConfigurationFloatingDevicesListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('MAC') }), // re-label
  pfConfigurationListFields.ip
]

export const pfConfigurationRealmsListFields = [
  pfConfigurationListFields.id
]

export const pfConfigurationRolesListFields = [
  pfConfigurationListFields.id,
  pfConfigurationListFields.notes
]

export const pfConfigurationAuthenticationSourcesViewFields = ({ isNew = false, isClone = false, sourceClass = null } = {}) => {
  switch (sourceClass) {
    case 'AD':
      return [
        {
          label: i18n.t('Name'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Name is required.')]: required,
                [i18n.t('Alphanumeric value required.')]: alphaNum,
                [i18n.t('Source exists.')]: not(and(required, conditional(isNew || isClone), sourceExists))
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
          fields: [
            {
              key: 'description',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Host'),
          fields: [
            {
              key: 'host',
              component: pfFormInput,
              attrs: {
                placeholder: i18n.t('Host'),
                class: 'col-sm-4'
              }
            },
            {
              text: ':',
              class: 'mx-1'
            },
            {
              key: 'port',
              component: pfFormInput,
              attrs: {
                placeholder: i18n.t('Port'),
                class: 'col-sm-1'
              },
              validators: {
                [i18n.t('Enter a valid port number.')]: isPort
              }
            },
            {
              key: 'encryption',
              component: pfFormSelect,
              attrs: {
                options: [
                  { value: 'none', text: i18n.t('None') },
                  { value: 'ssl', text: 'SSL' },
                  { value: 'starttls', text: 'Start TLS' }
                ]
              }
            }
          ]
        }
      ]
    default:
      return [
        {
          label: i18n.t('Name'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Name is required.')]: required,
                [i18n.t('Alphanumeric value required.')]: alphaNum,
                [i18n.t('Source exists.')]: not(and(required, conditional(isNew || isClone), sourceExists))
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
          fields: [
            {
              key: 'description',
              component: pfFormInput
            }
          ]
        }
      ]
  }
}

export const pfConfigurationDomainsViewFields = ({ isNew = false, isClone = false } = {}) => {
  return [
    {
      label: i18n.t('Identifier'),
      text: i18n.t('Specify a unique identifier for your configuration.<br/>This doesn\'t have to be related to your domain.'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew)
          },
          validators: {
            [i18n.t('Name is required.')]: required,
            [i18n.t('Alphanumeric value required.')]: alphaNum
          }
        }
      ]
    },
    {
      label: i18n.t('Workgroup'),
      fields: [
        {
          key: 'workgroup',
          component: pfFormInput,
          validators: {
            [i18n.t('Workgroup is required.')]: required
          }
        }
      ]
    },
    {
      label: i18n.t('DNS name of the domain'),
      text: i18n.t('The DNS name (FQDN) of the domain.'),
      fields: [
        {
          key: 'dns_name',
          component: pfFormInput,
          validators: {
            [i18n.t('DNS name is required.')]: required,
            [i18n.t('Fully Qualified Domain Name required.')]: isFQDN
          }
        }
      ]
    },
    {
      label: i18n.t('This server\'s name'),
      text: i18n.t('This server\'s name (account name) in your Active Directory. Use \'%h\' to automatically use this server hostname.'),
      fields: [
        {
          key: 'server_name',
          component: pfFormInput,
          validators: {
            [i18n.t('Server name is required.')]: required
          }
        }
      ]
    },
    {
      label: i18n.t('Sticky DC'),
      text: i18n.t('This is used to specify a sticky domain controller to connect to. If not specified, default \'*\' will be used to connect to any available domain controller.'),
      fields: [
        {
          key: 'sticky_dc',
          component: pfFormInput,
          validators: {
            [i18n.t('Sticky DC is required.')]: required
          }
        }
      ]
    },
    {
      label: i18n.t('Active Directory server'),
      text: i18n.t('The IP address or DNS name of your Active Directory server.'),
      fields: [
        {
          key: 'ad_server',
          component: pfFormInput,
          validators: {
            [i18n.t('Active Directory server is required.')]: required
          }
        }
      ]
    },
    {
      label: i18n.t('Username'),
      text: i18n.t('The username of a Domain Admin to use to join the server to the domain.'),
      fields: [
        {
          key: 'bind_dn',
          component: pfFormInput
        }
      ]
    },
    {
      label: i18n.t('Password'),
      text: i18n.t('The password of a Domain Admin to use to join the server to the domain. Will not be stored permanently and is only used while joining the domain.'),
      fields: [
        {
          key: 'bind_pass',
          component: pfFormInput,
          attrs: {
            type: 'password'
          }
        }
      ]
    }
  ]
}

export const pfConfigurationFloatingDevicesViewFields = ({ isNew = false, isClone = false } = {}) => {
  return [
    {
      label: i18n.t('MAC Address'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew)
          },
          validators: {
            [i18n.t('MAC address is required.')]: required,
            [i18n.t('Enter a valid MAC address.')]: macAddress()
          }
        }
      ]
    },
    {
      label: i18n.t('IP Address'),
      fields: [
        {
          key: 'ip',
          component: pfFormInput,
          validators: {
            [i18n.t('IP address is required.')]: required,
            [i18n.t('Enter a valid IP address.')]: ipAddress
          }
        }
      ]
    },
    {
      label: i18n.t('Native VLAN'),
      text: i18n.t('VLAN in which PacketFence should put the port.'),
      fields: [
        {
          key: 'pvid',
          component: pfFormInput,
          attrs: {
            filter: regExp.integerPositive
          },
          validators: {
            [i18n.t('Native VLAN is required.')]: required,
            [i18n.t('Enter a valid Native VLAN.')]: integer
          }
        }
      ]
    },
    {
      label: i18n.t('Trunk Port'),
      text: i18n.t('The port must be configured as a muti-vlan port.'),
      fields: [
        {
          key: 'trunkPort',
          component: pfFormToggle,
          attrs: {
            values: { checked: 'yes', unchecked: 'no' }
          }
        }
      ]
    },
    {
      label: i18n.t('Tagged VLANs'),
      text: i18n.t('Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.'),
      fields: [
        {
          key: 'taggedVlan',
          component: pfFormInput
        }
      ]
    }
  ]
}

export const pfConfigurationRealmViewFields = ({ isNew = false, isClone = false, domains = [] } = {}) => {
  return [
    {
      label: i18n.t('Realm'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew)
          },
          validators: {
            [i18n.t('Realm is required.')]: required,
            [i18n.t('Alphanumeric value required.')]: alphaNum
          }
        }
      ]
    },
    {
      label: i18n.t('Realm Options'),
      text: i18n.t('You can add FreeRADIUS options in the realm definition.'),
      fields: [
        {
          key: 'options',
          component: pfFormTextarea
        }
      ]
    },
    {
      label: i18n.t('Domain'),
      text: i18n.t('The domain to use for the authentication in that realm.'),
      fields: [
        {
          key: 'domain',
          component: pfFormSelect,
          attrs: {
            options: domains
          }
        }
      ]
    },
    {
      label: i18n.t('Strip on the portal'),
      text: i18n.t('Should the usernames matching this realm be stripped when used on the captive portal.'),
      fields: [
        {
          key: 'portal_strip_username',
          component: pfFormToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    },
    {
      label: i18n.t('Strip on the admin'),
      text: i18n.t('Should the usernames matching this realm be stripped when used on the administration interface.'),
      fields: [
        {
          key: 'admin_strip_username',
          component: pfFormToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    },
    {
      label: i18n.t('Strip in RADIUS authorization'),
      text: i18n.t('Should the usernames matching this realm be stripped when used in the authorization phase of 802.1x. Note that this doesn\'t control the stripping in FreeRADIUS, use the options above for that.'),
      fields: [
        {
          key: 'radius_strip_username',
          component: pfFormToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  ]
}

export const pfConfigurationRoleViewFields = ({ isNew = false, isClone = false } = {}) => {
  return [
    {
      label: i18n.t('Name'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew)
          },
          validators: {
            [i18n.t('Name is required.')]: required,
            [i18n.t('Alphanumeric value required.')]: alphaNum
          }
        }
      ]
    },
    {
      label: i18n.t('Description'),
      fields: [
        {
          key: 'notes',
          component: pfFormInput
        }
      ]
    },
    {
      label: i18n.t('Max nodes per user'),
      fields: [
        {
          key: 'max_nodes_per_pid',
          component: pfFormInput,
          attrs: {
            type: 'number'
          },
          validators: {
            [i18n.t('Max nodes per user required.')]: required,
            [i18n.t('Integer value required.')]: integer
          }
        }
      ]
    }
  ]
}

export const pfConfigurationAuthenticationSourcesViewDefaults = ({ isNew = false, isClone = false, sourceClass = null } = {}) => {
  return {
    id: null,
    port: 389
  }
}

export const pfConfigurationDomainsViewDefaults = ({ isNew = false, isClone = false } = {}) => {
  return {
    id: null,
    ad_server: '%h'
  }
}

export const pfConfigurationFloatingDevicesViewDefaults = ({ isNew = false, isClone = false } = {}) => {
  return {
    id: null
  }
}

export const pfConfigurationRealmViewDefaults = ({ isNew = false, isClone = false, domains = [] } = {}) => {
  return {
    id: null,
    portal_strip_username: 'enabled',
    admin_strip_username: 'enabled',
    radius_strip_username: 'enabled'
  }
}

export const pfConfigurationRoleViewDefaults = ({ isNew = false, isClone = false } = {}) => {
  return {
    id: null
  }
}
