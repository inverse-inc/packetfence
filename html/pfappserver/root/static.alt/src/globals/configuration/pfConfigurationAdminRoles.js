import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasAdminRoles,
  adminRoleExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationAdminRolesListColumns = [
  {
    key: 'id',
    label: i18n.t('Role Name'),
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

export const pfConfigurationAdminRolesListFields = [
  {
    value: 'id',
    text: i18n.t('Role Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationAdminRoleListConfig = (context = {}) => {
  return {
    columns: pfConfigurationAdminRolesListColumns,
    fields: pfConfigurationAdminRolesListFields,
    rowClickRoute (item, index) {
      return { name: 'admin_role', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/admin_roles',
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
      defaultRoute: { name: 'admin_roles' },
      resultsFilter: (adminRoles) => { // do not show protected defaults
        return adminRoles.filter(adminRole => !['ALL', 'ALL_PF_ONLY', 'NONE'].includes(adminRole.id))
      }
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

export const pfConfigurationAdminRoleActions = [
  {
    group: 'Admin Roles',
    items: [
      { text: 'Admin Roles - Create', value: 'ADMIN_ROLES_CREATE' },
      { text: 'Admin Roles - Delete', value: 'ADMIN_ROLES_DELETE' },
      { text: 'Admin Roles - Read', value: 'ADMIN_ROLES_READ' },
      { text: 'Admin Roles - Update', value: 'ADMIN_ROLES_UPDATE' }
    ]
  },
  {
    group: 'Auditing',
    items: [
      { text: 'Auditing - Read', value: 'AUDITING_READ' }
    ]
  },
  {
    group: 'Billing Tiers',
    items: [
      { text: 'Billing Tiers - Create', value: 'BILLING_TIER_CREATE' },
      { text: 'Billing Tiers - Delete', value: 'BILLING_TIER_DELETE' },
      { text: 'Billing Tiers - Read', value: 'BILLING_TIER_READ' },
      { text: 'Billing Tiers - Update', value: 'BILLING_TIER_UPDATE' }
    ]
  },
  {
    group: 'Main Configuration',
    items: [
      { text: 'Main Configuration - Read', value: 'CONFIGURATION_MAIN_READ' },
      { text: 'Main Configuration - Update', value: 'CONFIGURATION_MAIN_UPDATE' }
    ]
  },
  {
    group: 'Connection Profiles',
    items: [
      { text: 'Connection Profiles - Create', value: 'CONNECTION_PROFILES_CREATE' },
      { text: 'Connection Profiles - Delete', value: 'CONNECTION_PROFILES_DELETE' },
      { text: 'Connection Profiles - Read', value: 'CONNECTION_PROFILES_READ' },
      { text: 'Connection Profiles - Update', value: 'CONNECTION_PROFILES_UPDATE' }
    ]
  },
  {
    group: 'Device Registration',
    items: [
      { text: 'Device Registration - Create', value: 'DEVICE_REGISTRATION_CREATE' },
      { text: 'Device Registration - Delete', value: 'DEVICE_REGISTRATION_DELETE' },
      { text: 'Device Registration - Read', value: 'DEVICE_REGISTRATION_READ' },
      { text: 'Device Registration - Update', value: 'DEVICE_REGISTRATION_UPDATE' }
    ]
  },
  {
    group: 'DHCP Option 82 Log',
    items: [
      { text: 'DHCP Option 82 Log - Read', value: 'DHCP_OPTION_82_READ' }
    ]
  },
  {
    group: 'RADIUS Domains',
    items: [
      { text: 'RADIUS Domains - Create', value: 'DEVICE_REGISTRATION_CREATE' },
      { text: 'RADIUS Domains - Delete', value: 'DEVICE_REGISTRATION_DELETE' },
      { text: 'RADIUS Domains - Read', value: 'DEVICE_REGISTRATION_READ' },
      { text: 'RADIUS Domains - Update', value: 'DEVICE_REGISTRATION_UPDATE' }
    ]
  },
  {
    group: 'Filter Engines',
    items: [
      { text: 'Filter Engines - Read', value: 'FILTERS_READ' },
      { text: 'Filter Engines - Update', value: 'FILTERS_UPDATE' }
    ]
  },
  {
    group: 'Fingerbank',
    items: [
      { text: 'Fingerbank - Create', value: 'FINGERBANK_CREATE' },
      { text: 'Fingerbank - Delete', value: 'FINGERBANK_DELETE' },
      { text: 'Fingerbank - Read', value: 'FINGERBANK_READ' },
      { text: 'Fingerbank - Update', value: 'FINGERBANK_UPDATE' }
    ]
  },
  {
    group: 'Firewall SSO',
    items: [
      { text: 'Firewall SSO - Create', value: 'FIREWALL_SSO_CREATE' },
      { text: 'Firewall SSO - Delete', value: 'FIREWALL_SSO_DELETE' },
      { text: 'Firewall SSO - Read', value: 'FIREWALL_SSO_READ' },
      { text: 'Firewall SSO - Update', value: 'FIREWALL_SSO_UPDATE' }
    ]
  },
  {
    group: 'Floating Devices',
    items: [
      { text: 'Floating Devices - Create', value: 'FLOATING_DEVICES_CREATE' },
      { text: 'Floating Devices - Delete', value: 'FLOATING_DEVICES_DELETE' },
      { text: 'Floating Devices - Read', value: 'FLOATING_DEVICES_READ' },
      { text: 'Floating Devices - Update', value: 'FLOATING_DEVICES_UPDATE' }
    ]
  },
  {
    group: 'Interfaces',
    items: [
      { text: 'Interfaces - Create', value: 'INTERFACES_CREATE' },
      { text: 'Interfaces - Delete', value: 'INTERFACES_DELETE' },
      { text: 'Interfaces - Read', value: 'INTERFACES_READ' },
      { text: 'Interfaces - Update', value: 'INTERFACES_UPDATE' }
    ]
  },
  {
    group: 'MAC',
    items: [
      { text: 'MAC Addresses - Read', value: 'MAC_READ' },
      { text: 'MAC Addresses - Update', value: 'MAC_UPDATE' }
    ]
  },
  {
    group: 'MSE',
    items: [
      { text: 'MSE - Read', value: 'MSE_READ' }
    ]
  },
  {
    group: 'Nodes',
    items: [
      { text: 'Nodes - Create', value: 'NODES_CREATE' },
      { text: 'Nodes - Delete', value: 'NODES_DELETE' },
      { text: 'Nodes - Read', value: 'NODES_READ' },
      { text: 'Nodes - Update', value: 'NODES_UPDATE' }
    ]
  },
  {
    group: 'Syslog Parsers',
    items: [
      { text: 'Syslog Parsers - Create', value: 'PFDETECT_CREATE' },
      { text: 'Syslog Parsers - Delete', value: 'PFDETECT_DELETE' },
      { text: 'Syslog Parsers - Read', value: 'PFDETECT_READ' },
      { text: 'Syslog Parsers - Update', value: 'PFDETECT_UPDATE' }
    ]
  },
  {
    group: 'PFMON',
    items: [
      { text: 'PFMON - Read', value: 'PFMON_READ' },
      { text: 'PFMON - Update', value: 'PFMON_UPDATE' }
    ]
  },
  {
    group: 'PKI Providers',
    items: [
      { text: 'PKI Providers - Create', value: 'PKI_PROVIDER_CREATE' },
      { text: 'PKI Providers - Delete', value: 'PKI_PROVIDER_DELETE' },
      { text: 'PKI Providers - Read', value: 'PKI_PROVIDER_READ' },
      { text: 'PKI Providers - Update', value: 'PKI_PROVIDER_UPDATE' }
    ]
  },
  {
    group: 'Portal Modules',
    items: [
      { text: 'Portal Modules - Create', value: 'PORTAL_MODULE_CREATE' },
      { text: 'Portal Modules - Delete', value: 'PORTAL_MODULE_DELETE' },
      { text: 'Portal Modules - Read', value: 'PORTAL_MODULE_READ' },
      { text: 'Portal Modules - Update', value: 'PORTAL_MODULE_UPDATE' }
    ]
  },
  {
    group: 'Provisioning',
    items: [
      { text: 'Provisioning - Create', value: 'PROVISIONING_CREATE' },
      { text: 'Provisioning - Delete', value: 'PROVISIONING_DELETE' },
      { text: 'Provisioning - Read', value: 'PROVISIONING_READ' },
      { text: 'Provisioning - Update', value: 'PROVISIONING_UPDATE' }
    ]
  },
  {
    group: 'RADIUS Audit Log',
    items: [
      { text: 'RADIUS Audit Log - Read', value: 'RADIUS_LOG_READ' }
    ]
  },
  {
    group: 'RADIUS Realms',
    items: [
      { text: 'RADIUS Realms - Create', value: 'REALM_CREATE' },
      { text: 'RADIUS Realms - Delete', value: 'REALM_DELETE' },
      { text: 'RADIUS Realms - Read', value: 'REALM_READ' },
      { text: 'RADIUS Realms - Update', value: 'REALM_UPDATE' }
    ]
  },
  {
    group: 'Reports',
    items: [
      { text: 'Reports', value: 'REPORTS_READ' }
    ]
  },
  {
    group: 'Scan Engines',
    items: [
      { text: 'Scan Engines - Create', value: 'SCAN_CREATE' },
      { text: 'Scan Engines - Delete', value: 'SCAN_DELETE' },
      { text: 'Scan Engines - Read', value: 'SCAN_READ' },
      { text: 'Scan Engines - Update', value: 'SCAN_UPDATE' }
    ]
  },
  {
    group: 'Security Events',
    items: [
      { text: 'Security Events - Create', value: 'SECURITY_EVENTS_CREATE' },
      { text: 'Security Events - Delete', value: 'SECURITY_EVENTS_DELETE' },
      { text: 'Security Events - Read', value: 'SECURITY_EVENTS_READ' },
      { text: 'Security Events - Update', value: 'SECURITY_EVENTS_UPDATE' }
    ]
  },
  {
    group: 'Services',
    items: [
      { text: 'Services', value: 'SERVICES_READ' }
    ]
  },
  {
    group: 'Switches',
    items: [
      { text: 'Switches - Create', value: 'SWITCHES_CREATE' },
      { text: 'Switches - Delete', value: 'SWITCHES_DELETE' },
      { text: 'Switches - Read', value: 'SWITCHES_READ' },
      { text: 'Switches - Update', value: 'SWITCHES_UPDATE' }
    ]
  },
  {
    group: 'Switches CLI',
    items: [
      { text: 'Switches CLI - Read', value: 'SWITCH_LOGIN_READ' },
      { text: 'Switches CLI - Write', value: 'SWITCH_LOGIN_WRITE' }
    ]
  },
  {
    group: 'Syslog',
    items: [
      { text: 'Syslog - Create', value: 'SYSLOG_CREATE' },
      { text: 'Syslog - Delete', value: 'SYSLOG_DELETE' },
      { text: 'Syslog - Read', value: 'SYSLOG_READ' },
      { text: 'Syslog - Update', value: 'SYSLOG_UPDATE' }
    ]
  },
  {
    group: 'System',
    items: [
      { text: 'System - Create', value: 'SYSTEM_CREATE' },
      { text: 'System - Delete', value: 'SYSTEM_DELETE' },
      { text: 'System - Read', value: 'SYSTEM_READ' },
      { text: 'System - Update', value: 'SYSTEM_UPDATE' }
    ]
  },
  {
    group: 'Traffic Shaping',
    items: [
      { text: 'Traffic Shaping - Create', value: 'TRAFFIC_SHAPING_CREATE' },
      { text: 'Traffic Shaping - Delete', value: 'TRAFFIC_SHAPING_DELETE' },
      { text: 'Traffic Shaping - Read', value: 'TRAFFIC_SHAPING_READ' },
      { text: 'Traffic Shaping - Update', value: 'TRAFFIC_SHAPING_UPDATE' }
    ]
  },
  {
    group: 'Users',
    items: [
      { text: 'Users - Create', value: 'USERS_CREATE' },
      { text: 'Users - Create Multiple', value: 'USERS_CREATE_MULTIPLE' },
      { text: 'Users - Delete', value: 'USERS_DELETE' },
      { text: 'Users - Read', value: 'USERS_READ' },
      { text: 'Users - Read Sponsor', value: 'USERS_READ_SPONSORED' },
      { text: 'Users - Set Access Duration', value: 'USERS_SET_ACCESS_DURATION' },
      { text: 'Users - Set Access Level', value: 'USERS_SET_ACCESS_LEVEL' },
      { text: 'Users - Set Bandwidth Balance', value: 'USERS_SET_BANDWIDTH_BALANCE' },
      { text: 'Users - Set Role', value: 'USERS_SET_ROLE' },
      { text: 'Users - Set Tenant ID', value: 'USERS_SET_TENANT_ID' },
      { text: 'Users - Set Time Balance', value: 'USERS_SET_TIME_BALANCE' },
      { text: 'Users - Set Unreg Date', value: 'USERS_SET_UNREG_DATE' },
      { text: 'Users - Mark As Sponsor', value: 'USERS_MARK_AS_SPONSOR' },
      { text: 'Users - Update', value: 'USERS_UPDATE' }
    ]
  },
  {
    group: 'Users - Create Overwrite',
    items: [
      { text: 'Users - Create Overwrite', value: 'USERS_CREATE_OVERWRITE' }
    ]
  },
  {
    group: 'Users Roles',
    items: [
      { text: 'Users Roles - Create', value: 'USERS_ROLES_CREATE' },
      { text: 'Users Roles - Delete', value: 'USERS_ROLES_DELETE' },
      { text: 'Users Roles - Read', value: 'USERS_ROLES_READ' },
      { text: 'Users Roles - Update', value: 'USERS_ROLES_UPDATE' }
    ]
  },
  {
    group: 'Users Sources',
    items: [
      { text: 'Users Sources - Create', value: 'USERS_SOURCES_CREATE' },
      { text: 'Users Sources - Delete', value: 'USERS_SOURCES_DELETE' },
      { text: 'Users Sources - Read', value: 'USERS_SOURCES_READ' },
      { text: 'Users Sources - Update', value: 'USERS_SOURCES_UPDATE' }
    ]
  },
  {
    group: 'WMI Rules',
    items: [
      { text: 'WMI Rules - Create', value: 'WMI_CREATE' },
      { text: 'WMI Rules - Delete', value: 'WMI_DELETE' },
      { text: 'WMI Rules - Read', value: 'WMI_READ' },
      { text: 'WMI Rules - Update', value: 'WMI_UPDATE' }
    ]
  },
  {
    group: 'WRIX',
    items: [
      { text: 'WRIX - Create', value: 'WRIX_CREATE' },
      { text: 'WRIX - Delete', value: 'WRIX_DELETE' },
      { text: 'WRIX - Read', value: 'WRIX_READ' },
      { text: 'WRIX - Update', value: 'WRIX_UPDATE' }
    ]
  }
]

export const pfConfigurationAdminRoleViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    options: {
      meta = {}
    },
    form = {}
  } = context

  return [
    {
      tab: i18n.t('General'),
      fields: [
        {
          label: i18n.t('Name'),
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
                  [i18n.t('Admin Role exists.')]: not(and(required, conditional(isNew || isClone), hasAdminRoles, adminRoleExists))
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
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
          label: i18n.t('Actions'),
          fields: [
            {
              key: 'actions',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Action'),
                emptyText: i18n.t('With no actions specified, the admin will have no roles.'),
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        collapseObject: true,
                        placeholder: i18n.t('Click to select an action'),
                        groupLabel: 'group',
                        groupValues: 'items',
                        trackBy: 'value',
                        label: 'text',
                        options: pfConfigurationAdminRoleActions,
                        optionsLimit: 500

                      },
                      validators: {
                        [i18n.t('Action required.')]: required,
                        [i18n.t('Duplicate action.')]: conditional((value) => {
                          return !(form.actions.filter(v => v === value).length > 1)
                        })
                      }
                    }
                  }
                },
                invalidFeedback: [
                  { [i18n.t('Action(s) contain one or more errors.')]: true }
                ]
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('User Options'),
      fields: [
        {
          label: i18n.t('Allowed user access levels'),
          text: i18n.t('List of access levels available to the admin user. If none are provided then all access levels are available.'),
          fields: [
            {
              key: 'allowed_access_levels',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'allowed_access_levels'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'allowed_access_levels', i18n.t('Access Levels'))
            }
          ]
        },
        {
          label: i18n.t('Allowed user roles'),
          text: i18n.t('List of roles available to the admin user to assign to a user. If none are provided then all roles are available.'),
          fields: [
            {
              key: 'allowed_roles',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'allowed_roles'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'allowed_roles', i18n.t('Roles'))
            }
          ]
        },
        {
          label: i18n.t('Allowed user access durations'),
          text: i18n.t('A comma seperated list of access durations available to the admin user. If none are provided then the default access durations are used.'),
          fields: [
            {
              key: 'allowed_access_durations',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'allowed_access_durations'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'allowed_access_durations', i18n.t('Durations'))
            }
          ]
        },
        {
          label: i18n.t('Maximum allowed unregistration date'),
          text: i18n.t('The maximal unregistration date that can be set.'),
          fields: [
            {
              key: 'allowed_unreg_date',
              component: pfFormDatetime,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'allowed_unreg_date'),
                ...{
                  config: {
                    format: 'YYYY-MM-DD'
                  }
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'allowed_unreg_date', i18n.t('Datetime'))
            }
          ]
        },
        {
          label: i18n.t('Allowed actions'),
          text: i18n.t('List of actions available to the admin user. If none are provided then all actions are available.'),
          fields: [
            {
              key: 'allowed_actions',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'allowed_actions'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'allowed_actions', i18n.t('Actions'))
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Node Options'),
      fields: [
        {
          label: i18n.t('Allowed node roles'),
          text: i18n.t('List of roles available to the admin user to assign to a node. If none are provided then all roles are available.'),
          fields: [
            {
              key: 'allowed_node_roles',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'allowed_node_roles'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'allowed_node_roles', i18n.t('Roles'))
            }
          ]
        }
      ]
    }
  ]
}
