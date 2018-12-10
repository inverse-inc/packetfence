import i18n from '@/utils/locale'
import bytes from '@/utils/bytes'
import pfFieldAction from '@/components/pfFieldAction'
import pfFieldCondition from '@/components/pfFieldCondition'
import pfFieldRule from '@/components/pfFieldRule'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import { pfAuthenticationConditionType as authenticationConditionType } from '@/globals/pfAuthenticationConditions'
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  compareDate,
  isDateFormat,
  isFQDN,
  isPort,
  isPrice,
  sourceExists,
  requireAllSiblingFields,
  requireAnySiblingFields,
  restrictAllSiblingFields,
  limitSiblingFields
} from '@/globals/pfValidators'

const {
  required,
  alphaNum,
  integer,
  numeric,
  macAddress,
  ipAddress,
  maxLength,
  minValue,
  maxValue
} = require('vuelidate/lib/validators')

export const pfConfigurationActions = {
  set_access_duration: {
    value: 'set_access_duration',
    text: i18n.t('Access duration'),
    types: [fieldType.DURATION],
    validators: {
      type: {
        /* Require "set_role" */
        [i18n.t('Action requires "Set Role".')]: requireAllSiblingFields('type', 'set_role'),
        /* Restrict "set_unreg_date" */
        [i18n.t('Action conflicts with "Unregistration date".')]: restrictAllSiblingFields('type', 'set_unreg_date'),
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_access_level: {
    value: 'set_access_level',
    text: i18n.t('Access level'),
    types: [fieldType.ADMINROLE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_bandwidth_balance: {
    value: 'set_bandwidth_balance',
    text: i18n.t('Bandwidth balance'),
    types: [fieldType.PREFIXMULTIPLIER],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Value must be greater than {min}bytes.', { min: bytes.toHuman(schema.node.bandwidth_balance.min) })]: minValue(schema.node.bandwidth_balance.min),
        [i18n.t('Value must be less than {max}bytes.', { max: bytes.toHuman(schema.node.bandwidth_balance.max) })]: maxValue(schema.node.bandwidth_balance.max)
      }
    }
  },
  mark_as_sponsor: {
    value: 'mark_as_sponsor',
    text: i18n.t('Mark as sponsor'),
    types: [fieldType.NONE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      }
    }
  },
  set_role: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE],
    validators: {
      type: {
        /* When "Role" is selected, either "Time Balance" or "set_unreg_date" is required */
        [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: requireAnySiblingFields('type', 'set_access_duration', 'set_unreg_date'),
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_role_by_name: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE_BY_NAME],
    validators: {
      type: {
        /* When "Role" is selected, either "Time Balance" or "set_unreg_date" is required */
        [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: requireAnySiblingFields('type', 'set_access_duration', 'set_unreg_date'),
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_tenant_id: {
    value: 'set_tenant_id',
    text: i18n.t('Tenant ID'),
    types: [fieldType.TENANT],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Value must be numeric.')]: numeric
      }
    }
  },
  set_time_balance: {
    value: 'set_time_balance',
    text: i18n.t('Time balance'),
    types: [fieldType.DURATION],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  },
  set_unreg_date: {
    value: 'set_unreg_date',
    text: i18n.t('Unregistration date'),
    types: [fieldType.DATETIME],
    moments: ['1 days', '1 weeks', '1 months', '1 years'],
    validators: {
      type: {
        /* Require "set_role" */
        [i18n.t('Action requires "Set Role".')]: requireAllSiblingFields('type', 'set_role'),
        /* Restrict "set_access_duration" */
        [i18n.t('Action conflicts with "Access duration".')]: restrictAllSiblingFields('type', 'set_access_duration'),
        /* Don't allow elsewhere */
        [i18n.t('Duplicate action.')]: limitSiblingFields('type', 0)
      },
      value: {
        [i18n.t('Future date required.')]: compareDate('>=', new Date(), schema.node.unregdate.format, false),
        [i18n.t('Invalid date.')]: isDateFormat(schema.node.unregdate.format)
      }
    }
  }
}

export const pfConfigurationConditions = {
  cn: {
    value: 'cn',
    text: i18n.t('cn'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  computer_name: {
    value: 'computer_name',
    text: i18n.t('Computer Name'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  connection_type: {
    value: 'connection_type',
    text: i18n.t('Connection type'),
    types: [authenticationConditionType.CONNECTION],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  current_time: {
    value: 'current_time',
    text: i18n.t('Current time'),
    types: [authenticationConditionType.TIME],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  current_time_period: {
    value: 'current_time_period',
    text: i18n.t('Current time period'),
    types: [authenticationConditionType.TIMEPERIOD],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  department: {
    value: 'department',
    text: i18n.t('department'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  description: {
    value: 'description',
    text: i18n.t('description'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  displayName: {
    value: 'displayName',
    text: i18n.t('displayName'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  distinguishedName: {
    value: 'distinguishedName',
    text: i18n.t('distinguishedName'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  eduPersonPrimaryAffiliation: {
    value: 'eduPersonPrimaryAffiliation',
    text: i18n.t('eduPersonPrimaryAffiliation'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  givenName: {
    value: 'givenName',
    text: i18n.t('givenName'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  groupMembership: {
    value: 'groupMembership',
    text: i18n.t('groupMembership'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  mac: {
    value: 'mac',
    text: i18n.t('MAC Address'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  mail: {
    value: 'mail',
    text: i18n.t('mail'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  memberOf: {
    value: 'memberOf',
    text: i18n.t('memberOf'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  nested_group: {
    value: 'memberOf:1.2.840.113556.1.4.1941:',
    text: i18n.t('nested group'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  postOfficeBox: {
    value: 'postOfficeBox',
    text: i18n.t('postOfficeBox'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  realm: {
    value: 'realm',
    text: i18n.t('Realm'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  sAMAccountName: {
    value: 'sAMAccountName',
    text: i18n.t('sAMAccountName'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  sAMAccountType: {
    value: 'sAMAccountType',
    text: i18n.t('sAMAccountType'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  sn: {
    value: 'sn',
    text: i18n.t('sn'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  ssid: {
    value: 'SSID',
    text: i18n.t('SSID'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  uid: {
    value: 'uid',
    text: i18n.t('uid'),
    types: [authenticationConditionType.LDAPATTRIBUTE],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  },
  userAccountControl: {
    value: 'userAccountControl',
    text: i18n.t('userAccountControl'),
    types: [authenticationConditionType.SUBSTRING],
    validators: {
      operator: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255)
      }
    }
  }
}

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
    label: null, // multiple occurances w/ different strings, nullify for overload
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
  name: {
    key: 'name',
    label: i18n.t('Name'),
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
  price: {
    key: 'price',
    label: i18n.t('Price'),
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
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Name') }), // re-label
  pfConfigurationListColumns.description,
  pfConfigurationListColumns.class,
  pfConfigurationListColumns.type,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationDomainsListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Name') }), // re-label
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
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Name') }), // re-label
  pfConfigurationListColumns.portal_strip_username,
  pfConfigurationListColumns.admin_strip_username,
  pfConfigurationListColumns.radius_strip_username
]

export const pfConfigurationRolesListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Name') }), // re-label
  pfConfigurationListColumns.notes,
  pfConfigurationListColumns.max_nodes_per_pid,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationBillingTiersListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Identifier') }), // re-label
  pfConfigurationListColumns.name,
  pfConfigurationListColumns.price
]

export const pfConfigurationListFields = {
  id: {
    value: 'id',
    text: null, // multiple occurances w/ different strings, nullify for overload
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
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Name') }), // re-text
  pfConfigurationListFields.description,
  pfConfigurationListFields.class,
  pfConfigurationListFields.type
]

export const pfConfigurationBillingTiersListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Identifier') }), // re-text
  pfConfigurationListFields.description
]

export const pfConfigurationDomainsListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Name') }), // re-text
  pfConfigurationListFields.workgroup
]

export const pfConfigurationFloatingDevicesListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('MAC') }), // re-text
  pfConfigurationListFields.ip
]

export const pfConfigurationRealmsListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Name') }) // re-text
]

export const pfConfigurationRolesListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Name') }), // re-text
  pfConfigurationListFields.notes
]

export const pfConfigurationViewFields = {
  id: ({ isNew = false, isClone = false } = {}) => {
    return {
      label: i18n.t('Name'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew && !isClone)
          },
          validators: {
            [i18n.t('Value required.')]: required,
            [i18n.t('Alphanumeric characters only.')]: alphaNum,
            [i18n.t('Source exists.')]: not(and(required, conditional(isNew || isClone), sourceExists))
          }
        }
      ]
    }
  },
  description: {
    label: i18n.t('Description'),
    fields: [
      {
        key: 'description',
        component: pfFormInput,
        validators: {
          [i18n.t('Description required.')]: required
        }
      }
    ]
  },
  access_scope: { // renamed from 'scope'
    label: i18n.t('Scope'),
    text: i18n.t('The permissions the application requests.'),
    fields: [
      {
        key: 'scope',
        component: pfFormInput,
        validators: {
          [i18n.t('Scope required.')]: required
        }
      }
    ]
  },
  access_token_param: {
    label: i18n.t('Access Token Parameter'),
    fields: [
      {
        key: 'access_token_param',
        component: pfFormInput,
        validators: {
          [i18n.t('Parameter required.')]: required
        }
      }
    ]
  },
  access_token_path: {
    label: null, // multiple occurances w/ different strings, nullify for overload
    fields: [
      {
        key: 'access_token_path',
        component: pfFormInput,
        validators: {
          [i18n.t('Path required.')]: required
        }
      }
    ]
  },
  account_sid: {
    label: i18n.t('Account SID'),
    text: i18n.t('Twilio Account SID'),
    fields: [
      {
        key: 'account_sid',
        component: pfFormInput,
        validators: {
          [i18n.t('SID required.')]: required
        }
      }
    ]
  },
  activation_domain: {
    label: i18n.t('Host in activation link'),
    text: i18n.t('Set this value if you want to change the hostname in the validation link. Changing this requires to restart haproxy to be fully effective.'),
    fields: [
      {
        key: 'activation_domain',
        component: pfFormInput
      }
    ]
  },
  administration_rules: ({ isNew = false, isClone = false } = {}) => {
    return {
      label: 'Administration Rules',
      fields: [
        {
          key: 'administration_rules',
          component: pfFormFields,
          attrs: {
            buttonLabel: 'Add Rule - New ( )',
            sortable: true,
            field: {
              component: pfFieldRule,
              attrs: {
                matchLabel: i18n.t('Select rule match'),
                actions: {
                  component: pfFieldAction,
                  attrs: {
                    typeLabel: i18n.t('Select action type'),
                    valueLabel: i18n.t('Select action value'),
                    fields: [
                      pfConfigurationActions.set_access_level,
                      pfConfigurationActions.mark_as_sponsor,
                      pfConfigurationActions.set_tenant_id
                    ]
                  },
                  invalidFeedback: [
                    { [i18n.t('Action(s) contain one or more errors.')]: true }
                  ]
                },
                conditions: {
                  component: pfFieldCondition,
                  attrs: {
                    attributeLabel: i18n.t('Select attribute'),
                    operatorLabel: i18n.t('Select operator'),
                    valueLabel: i18n.t('Select value'),
                    fields: [
                      pfConfigurationConditions.ssid,
                      pfConfigurationConditions.current_time,
                      pfConfigurationConditions.current_time_period,
                      pfConfigurationConditions.connection_type,
                      pfConfigurationConditions.computer_name,
                      pfConfigurationConditions.mac,
                      pfConfigurationConditions.realm,
                      pfConfigurationConditions.cn,
                      pfConfigurationConditions.department,
                      pfConfigurationConditions.description,
                      pfConfigurationConditions.displayName,
                      pfConfigurationConditions.distinguishedName,
                      pfConfigurationConditions.eduPersonPrimaryAffiliation,
                      pfConfigurationConditions.givenName,
                      pfConfigurationConditions.groupMembership,
                      pfConfigurationConditions.mail,
                      pfConfigurationConditions.memberOf,
                      pfConfigurationConditions.nested_group,
                      pfConfigurationConditions.postOfficeBox,
                      pfConfigurationConditions.sAMAccountName,
                      pfConfigurationConditions.sAMAccountType,
                      pfConfigurationConditions.sn,
                      pfConfigurationConditions.uid,
                      pfConfigurationConditions.userAccountControl
                    ]
                  },
                  invalidFeedback: [
                    { [i18n.t('Condition(s) contain one or more errors.')]: true }
                  ]
                }
              },
              validators: {
                id: {
                  [i18n.t('Name required.')]: required,
                  [i18n.t('Alphanumeric characters only.')]: alphaNum,
                  [i18n.t('Maximum 255 characters.')]: maxLength(255),
                  [i18n.t('Duplicate name.')]: limitSiblingFields('id', 0)
                },
                description: {
                  [i18n.t('Maximum 255 characters.')]: maxLength(255)
                },
                match: {
                  [i18n.t('Match required.')]: required
                }
              }
            },
            invalidFeedback: [
              { [i18n.t('Rule(s) contain one or more errors.')]: true }
            ]
          }
        }
      ]
    }
  },
  allow_localdomain: {
    label: i18n.t('Allow Local Domain'),
    text: i18n.t('Accept self-registration with email address from the local domain'),
    fields: [
      {
        key: 'allow_localdomain',
        component: pfFormToggle,
        attrs: {
          values: { checked: 'yes', unchecked: 'no' }
        }
      }
    ]
  },
  api_key: {
    label: i18n.t('API Key'),
    text: i18n.t('Kickbox.io API key.'),
    fields: [
      {
        key: 'api_key',
        component: pfFormInput,
        validators: {
          [i18n.t('Key required.')]: required
        }
      }
    ]
  },
  api_login_id: {
    label: i18n.t('API login ID'),
    fields: [
      {
        key: 'api_login_id',
        component: pfFormInput,
        validators: {
          [i18n.t('ID required.')]: required
        }
      }
    ]
  },
  api_username: {
    label: i18n.t('API username (basic auth)'),
    fields: [
      {
        key: 'username',
        component: pfFormInput
      }
    ]
  },
  api_password: {
    label: i18n.t('API password (basic auth)'),
    fields: [
      {
        key: 'password',
        component: pfFormPassword
      }
    ]
  },
  auth_listening_port: {
    label: i18n.t('Authentication listening port'),
    text: i18n.t('PacketFence Eduroam RADIUS virtual server authentication listening port'),
    fields: [
      {
        key: 'auth_listening_port',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Enter a valid port number')]: isPort
        }
      }
    ]
  },
  auth_token: {
    label: i18n.t('Auth Token'),
    text: i18n.t('Twilio Auth Token'),
    fields: [
      {
        key: 'auth_token',
        component: pfFormInput,
        validators: {
          [i18n.t('Token required.')]: required
        }
      }
    ]
  },
  authenticate_realm: {
    label: i18n.t('Realm to use to authenticate'),
    fields: [
      {
        key: 'authenticate_realm',
        component: pfFormInput,
        validators: {
          [i18n.t('Realm required.')]: required
        }
      }
    ]
  },
  authentication_rules: ({ isNew = false, isClone = false } = {}) => {
    return {
      label: 'Authentication Rules',
      fields: [
        {
          key: 'authentication_rules',
          component: pfFormFields,
          attrs: {
            buttonLabel: 'Add Rule - New ( )',
            sortable: true,
            field: {
              component: pfFieldRule,
              attrs: {
                matchLabel: i18n.t('Select rule match'),
                actions: {
                  component: pfFieldAction,
                  attrs: {
                    typeLabel: i18n.t('Select action type'),
                    valueLabel: i18n.t('Select action value'),
                    fields: [
                      pfConfigurationActions.set_role_by_name,
                      pfConfigurationActions.set_access_duration,
                      pfConfigurationActions.set_unreg_date,
                      pfConfigurationActions.set_time_balance,
                      pfConfigurationActions.set_bandwidth_balance
                    ]
                  },
                  invalidFeedback: [
                    { [i18n.t('Action(s) contain one or more errors.')]: true }
                  ]
                },
                conditions: {
                  component: pfFieldCondition,
                  attrs: {
                    attributeLabel: i18n.t('Select attribute'),
                    operatorLabel: i18n.t('Select operator'),
                    valueLabel: i18n.t('Select value'),
                    fields: [
                      pfConfigurationConditions.ssid,
                      pfConfigurationConditions.current_time,
                      pfConfigurationConditions.current_time_period,
                      pfConfigurationConditions.connection_type,
                      pfConfigurationConditions.computer_name,
                      pfConfigurationConditions.mac,
                      pfConfigurationConditions.realm,
                      pfConfigurationConditions.cn,
                      pfConfigurationConditions.department,
                      pfConfigurationConditions.description,
                      pfConfigurationConditions.displayName,
                      pfConfigurationConditions.distinguishedName,
                      pfConfigurationConditions.eduPersonPrimaryAffiliation,
                      pfConfigurationConditions.givenName,
                      pfConfigurationConditions.groupMembership,
                      pfConfigurationConditions.mail,
                      pfConfigurationConditions.memberOf,
                      pfConfigurationConditions.nested_group,
                      pfConfigurationConditions.postOfficeBox,
                      pfConfigurationConditions.sAMAccountName,
                      pfConfigurationConditions.sAMAccountType,
                      pfConfigurationConditions.sn,
                      pfConfigurationConditions.uid,
                      pfConfigurationConditions.userAccountControl
                    ]
                  },
                  invalidFeedback: [
                    { [i18n.t('Condition(s) contain one or more errors.')]: true }
                  ]
                }
              },
              validators: {
                id: {
                  [i18n.t('Name required.')]: required,
                  [i18n.t('Alphanumeric characters only.')]: alphaNum,
                  [i18n.t('Maximum 255 characters.')]: maxLength(255),
                  [i18n.t('Duplicate name.')]: limitSiblingFields('id', 0)
                },
                description: {
                  [i18n.t('Maximum 255 characters.')]: maxLength(255)
                },
                match: {
                  [i18n.t('Match required.')]: required
                }
              }
            },
            invalidFeedback: [
              { [i18n.t('Rule(s) contain one or more errors.')]: true }
            ]
          }
        }
      ]
    }
  },
  authorization_source_id: ({ sources = [] } = {}) => {
    return {
      label: i18n.t('Authorization source'),
      text: i18n.t('The source to use for authorization (rule matching)'),
      fields: [
        {
          key: 'authorization_source_id',
          component: pfFormChosen,
          attrs: {
            placeholder: i18n.t('Choose Internal Source'),
            collapseObject: true,
            trackBy: 'value',
            label: 'text',
            options: sources.filter(source => source.class === 'internal').map(source => { return { value: source.id, text: `${source.id} - ${source.description}` } }) // internal sources only
          },
          validators: {
            [i18n.t('Authentication source required.')]: required
          }
        }
      ]
    }
  },
  authentication_url: {
    label: i18n.t('Authentication URL'),
    text: i18n.t('Note : The URL is always prefixed by a slash (/)'),
    fields: [
      {
        key: 'authentication_url',
        component: pfFormInput,
        validators: {
          [i18n.t('URL required.')]: required
        }
      }
    ]
  },
  authorization_url: {
    label: i18n.t('Authorization URL'),
    text: i18n.t('Note : The URL is always prefixed by a slash (/)'),
    fields: [
      {
        key: 'authorization_url',
        component: pfFormInput,
        validators: {
          [i18n.t('URL required.')]: required
        }
      }
    ]
  },
  authorize_path: {
    label: i18n.t('API Authorize Path'),
    fields: [
      {
        key: 'authorize_path',
        component: pfFormInput,
        validators: {
          [i18n.t('URL required.')]: required
        }
      }
    ]
  },
  base_url: {
    label: i18n.t('Iframe Base url'),
    fields: [
      {
        key: 'currency',
        component: pfFormSelect,
        attrs: {
          options: [
            { value: 'https://staging.eigendev.com/MiraSecure/GetToken.php', text: 'Staging' },
            { value: 'https://ms1.eigendev.com/MiraSecure/GetToken.php', text: 'Production 1' },
            { value: 'https://ms2.eigendev.com/MiraSecure/GetToken.php', text: 'Production 2' }
          ]
        },
        validators: {
          [i18n.t('URL required.')]: required
        }
      }
    ]
  },
  basedn: {
    label: i18n.t('Base DN'),
    fields: [
      {
        key: 'basedn',
        component: pfFormInput,
        validators: {
          [i18n.t('Base DN required.')]: required
        }
      }
    ]
  },
  binddn: {
    label: i18n.t('Bind DN'),
    text: i18n.t('Leave this field empty if you want to perform an anonymous bind.'),
    fields: [
      {
        key: 'binddn',
        component: pfFormInput
      }
    ]
  },
  cache_match: {
    label: i18n.t('Cache match'),
    text: i18n.t('Will cache results of matching a rule'),
    fields: [
      {
        key: 'cache_match',
        component: pfFormToggle,
        attrs: {
          values: { checked: '1', unchecked: '0' }
        }
      }
    ]
  },
  cert_file: {
    label: i18n.t('Cert file'),
    text: i18n.t('The path to the certificate you submitted to Paypal.'),
    fields: [
      {
        key: 'cert_file',
        component: pfFormInput,
        validators: {
          [i18n.t('File required.')]: required
        }
      }
    ]
  },
  cert_id: {
    label: i18n.t('Cert id'),
    fields: [
      {
        key: 'cert_id',
        component: pfFormInput,
        validators: {
          [i18n.t('ID required.')]: required
        }
      }
    ]
  },
  client_id: {
    label: i18n.t('App ID'),
    fields: [
      {
        key: 'client_id',
        component: pfFormInput,
        validators: {
          [i18n.t('ID required.')]: required
        }
      }
    ]
  },
  client_secret: {
    label: i18n.t('App Secret'),
    fields: [
      {
        key: 'client_secret',
        component: pfFormInput,
        validators: {
          [i18n.t('Secret required.')]: required
        }
      }
    ]
  },
  connection_timeout: {
    label: i18n.t('Connection timeout'),
    text: i18n.t('LDAP connection Timeout'),
    fields: [
      {
        key: 'connection_timeout',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Integer values required.')]: integer
        }
      }
    ]
  },
  create_local_account: {
    label: i18n.t('Create Local Account'),
    text: i18n.t('Create a local account on the PacketFence system based on the username provided.'),
    fields: [
      {
        key: 'create_local_account',
        component: pfFormToggle,
        attrs: {
          values: { checked: 'yes', unchecked: 'no' }
        }
      }
    ]
  },
  currency: {
    label: i18n.t('Currency'),
    fields: [
      {
        key: 'currency',
        component: pfFormSelect,
        attrs: {
          options: [
            { value: 'USD', text: 'USD' },
            { value: 'CAD', text: 'CAD' }
          ]
        }
      }
    ]
  },
  direct_base_url: {
    label: i18n.t('Direct Base url'),
    fields: [
      {
        key: 'direct_base_url',
        component: pfFormInput,
        validators: {
          [i18n.t('URL required.')]: required
        }
      }
    ]
  },
  domains: {
    label: i18n.t('Authorized domains'),
    text: i18n.t('Comma separated list of domains that will be resolve with the correct IP addresses.'),
    fields: [
      {
        key: 'domains',
        component: pfFormInput,
        validators: {
          [i18n.t('Domain(s) required.')]: required
        }
      }
    ]
  },
  email_activation_timeout: {
    label: i18n.t('Email Activation Timeout'),
    text: null, // multiple occurances w/ different strings, nullify for overload
    fields: [
      {
        key: 'email_activation_timeout.interval',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Interval required.')]: required,
          [i18n.t('Integer values required.')]: integer
        }
      },
      {
        key: 'email_activation_timeout.unit',
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
        },
        validators: {
          [i18n.t('Unit required.')]: required
        }
      }
    ]
  },
  email_address: {
    label: i18n.t('Email address'),
    text: i18n.t('The email address associated to your paypal account.'),
    fields: [
      {
        key: 'email_address',
        component: pfFormInput,
        validators: {
          [i18n.t('Email address required.')]: required
        }
      }
    ]
  },
  email_attribute: {
    label: i18n.t('Email Attribute'),
    text: i18n.t('LDAP attribute name that stores the email address against which the filter will match.'),
    fields: [
      {
        key: 'email_attribute',
        component: pfFormInput
      }
    ]
  },
  email_required: {
    label: i18n.t('Email required'),
    fields: [
      {
        key: 'email_required',
        component: pfFormToggle,
        attrs: {
          values: { checked: 'yes', unchecked: 'no' }
        }
      }
    ]
  },
  group_header: {
    label: i18n.t('Group header '),
    fields: [
      {
        key: 'group_header',
        component: pfFormInput,
        validators: {
          [i18n.t('Header required.')]: required
        }
      }
    ]
  },
  host: {
    label: i18n.t('Host'),
    fields: [
      {
        key: 'host',
        component: pfFormInput,
        validators: {
          [i18n.t('Host required.')]: required
        }
      }
    ]
  },
  host_port_encryption: {
    label: i18n.t('Host'),
    fields: [
      {
        key: 'host',
        component: pfFormInput,
        attrs: {
          class: 'col-sm-4'
        }
      },
      {
        text: ':',
        class: 'mx-1 font-weight-bold'
      },
      {
        key: 'port',
        component: pfFormInput,
        attrs: {
          class: 'col-sm-1',
          type: 'number'
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
  },
  identity_token: {
    label: i18n.t('Identity token'),
    fields: [
      {
        key: 'identity_token',
        component: pfFormInput,
        validators: {
          [i18n.t('Path required.')]: required
        }
      }
    ]
  },
  idp_ca_cert_path: {
    label: i18n.t('Path to Identity Provider CA cert (x509)'),
    text: i18n.t('If your Identity Provider uses a self-signed certificate, put the path to its certificate here instead.'),
    fields: [
      {
        key: 'idp_ca_cert_path',
        component: pfFormInput,
        validators: {
          [i18n.t('Path required.')]: required
        }
      }
    ]
  },
  idp_cert_path: {
    label: i18n.t('Path to Identity Provider cert (x509)'),
    fields: [
      {
        key: 'idp_cert_path',
        component: pfFormInput,
        validators: {
          [i18n.t('Path required.')]: required
        }
      }
    ]
  },
  idp_entity_id: {
    label: i18n.t('Identity Provider entity ID'),
    fields: [
      {
        key: 'idp_entity_id',
        component: pfFormInput,
        validators: {
          [i18n.t('ID required.')]: required
        }
      }
    ]
  },
  idp_metadata_path: {
    label: i18n.t('Path to Identity Provider metadata'),
    fields: [
      {
        key: 'idp_metadata_path',
        component: pfFormInput,
        validators: {
          [i18n.t('Path required.')]: required
        }
      }
    ]
  },
  key_file: {
    label: i18n.t('Key file'),
    text: i18n.t('The path to the associated key of the certificate you submitted to Paypal.'),
    fields: [
      {
        key: 'key_file',
        component: pfFormInput,
        validators: {
          [i18n.t('File required.')]: required
        }
      }
    ]
  },
  local_account_logins: {
    label: i18n.t('Amount of logins for the local account'),
    text: i18n.t('The amount of times, the local account can be used after its created. 0 means infinite.'),
    fields: [
      {
        key: 'local_account_logins',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Integer values required.')]: integer
        }
      }
    ]
  },
  local_realm: ({ realms = [] } = {}) => {
    return {
      label: i18n.t('Local Realms'),
      text: i18n.t('Realms that will be authenticate locally'),
      fields: [
        {
          key: 'local_realm',
          component: pfFormChosen,
          attrs: {
            collapseObject: true,
            placeholder: i18n.t('Click to add a realm'),
            trackBy: 'value',
            label: 'text',
            multiple: true,
            clearOnSelect: false,
            closeOnSelect: false,
            options: realms.map(realm => { return { value: realm.id.toLowerCase(), text: realm.id.toLowerCase() } })
          }
        }
      ]
    }
  },
  merchant_id: {
    label: i18n.t('Merchant ID'),
    fields: [
      {
        key: 'merchant_id',
        component: pfFormInput,
        validators: {
          [i18n.t('ID required.')]: required
        }
      }
    ]
  },
  message: {
    label: i18n.t('SMS text message ($pin will be replaced by the PIN number)'),
    fields: [
      {
        key: 'message',
        component: pfFormTextarea,
        attrs: {
          rows: 5
        }
      }
    ]
  },
  monitor: {
    label: i18n.t('Monitor'),
    text: i18n.t('Do you want to monitor this source?'),
    fields: [
      {
        key: 'monitor',
        component: pfFormToggle,
        attrs: {
          values: { checked: '1', unchecked: '0' }
        }
      }
    ]
  },
  password: ({ $store = {}, source = {} } = {}) => {
    return {
      label: i18n.t('Password'),
      fields: [
        {
          key: 'password',
          component: pfFormPassword,
          attrs: {
            test: () => {
              return $store.dispatch('$_sources/testAuthenticationSource', source).then(response => {
                return response
              }).catch(err => {
                throw err
              })
            }
          },
          validators: {
            [i18n.t('Password required.')]: required
          }
        }
      ]
    }
  },
  password_email_update: {
    label: i18n.t('Email'),
    text: i18n.t('Email addresses to send the new generated password.'),
    fields: [
      {
        key: 'password_email_update',
        component: pfFormInput,
        validators: {
          [i18n.t('Email required.')]: required
        }
      }
    ]
  },
  password_length: {
    label: i18n.t('Password length '),
    text: i18n.t('The length of the password to generate.'),
    fields: [
      {
        key: 'password_length',
        component: pfFormSelect,
        attrs: {
          options: Array(15).fill().map((_, i) => { return { value: i + 1, text: i + 1 } })
        },
        validators: {
          [i18n.t('Password length required.')]: required
        }
      }
    ]
  },
  password_rotation: {
    label: i18n.t('Password Rotation Period'),
    text: i18n.t('Period of time after the password must be rotated.'),
    fields: [
      {
        key: 'password_rotation.interval',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Interval required.')]: required,
          [i18n.t('Integer values required.')]: integer
        }
      },
      {
        key: 'password_rotation.unit',
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
        },
        validators: {
          [i18n.t('Unit required.')]: required
        }
      }
    ]
  },
  path: {
    label: i18n.t('File Path'),
    fields: [
      {
        key: 'path',
        component: pfFormInput,
        validators: {
          [i18n.t('Path required.')]: required
        }
      }
    ]
  },
  payment_type: {
    label: i18n.t('Payment type'),
    fields: [
      {
        key: 'payment_type',
        component: pfFormSelect,
        attrs: {
          options: [
            { value: '_xclick', text: i18n.t('Buy Now') },
            { value: '_donations', text: 'Donations' }
          ]
        },
        validators: {
          [i18n.t('Payment type required.')]: required
        }
      }
    ]
  },
  paypal_cert_file: {
    label: i18n.t('Paypal cert file'),
    text: i18n.t('The path to the Paypal certificate you downloaded.'),
    fields: [
      {
        key: 'paypal_cert_file',
        component: pfFormInput,
        validators: {
          [i18n.t('File required.')]: required
        }
      }
    ]
  },
  pin_code_length: {
    label: i18n.t('PIN length'),
    text: i18n.t('The amount of digits of the PIN number.'),
    fields: [
      {
        key: 'pin_code_length',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Pin length required.')]: required,
          [i18n.t('Integer values required.')]: integer
        }
      }
    ]
  },
  port: {
    label: i18n.t('Port'),
    fields: [
      {
        key: 'port',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Port required.')]: required,
          [i18n.t('Enter a valid port number')]: isPort
        }
      }
    ]
  },
  protected_resource_url: {
    label: null, // multiple occurances w/ different strings, nullify for overload
    fields: [
      {
        key: 'protected_resource_url',
        component: pfFormInput,
        validators: {
          [i18n.t('URL required.')]: required
        }
      }
    ]
  },
  protocol_ip_port: {
    label: i18n.t('Host'),
    fields: [
      {
        key: 'protocol',
        component: pfFormSelect,
        attrs: {
          options: [
            { value: 'http', text: 'http' },
            { value: 'https', text: 'https' }
          ]
        }
      },
      {
        key: 'ip',
        component: pfFormInput,
        attrs: {
          class: 'col-sm-4'
        },
        validators: {
          [i18n.t('Enter a valid IP address.')]: ipAddress
        }
      },
      {
        text: ':',
        class: 'mx-1 font-weight-bold'
      },
      {
        key: 'port',
        component: pfFormInput,
        attrs: {
          class: 'col-sm-1',
          type: 'number'
        },
        validators: {
          [i18n.t('Enter a valid port number.')]: isPort
        }
      }
    ]
  },
  proxy_addresses: {
    label: i18n.t('Proxy addresses'),
    text: i18n.t('A comma seperated list of IP Address'),
    fields: [
      {
        key: 'proxy_addresses',
        component: pfFormTextarea,
        attrs: {
          rows: 5
        },
        validators: {
          [i18n.t('Address(es) required.')]: required
        }
      }
    ]
  },
  public_client_key: {
    label: i18n.t('Public Client Key'),
    fields: [
      {
        key: 'public_client_key',
        component: pfFormInput,
        validators: {
          [i18n.t('Key required.')]: required
        }
      }
    ]
  },
  publishable_key: {
    label: i18n.t('Publishable key'),
    fields: [
      {
        key: 'publishable_key',
        component: pfFormInput
      }
    ]
  },
  radius_secret: {
    label: i18n.t('RADIUS secret'),
    text: i18n.t('Eduroam RADIUS secret'),
    fields: [
      {
        key: 'radius_secret',
        component: pfFormInput,
        validators: {
          [i18n.t('Secret required.')]: required
        }
      }
    ]
  },
  read_timeout: {
    label: i18n.t('Response timeout'),
    text: i18n.t('LDAP response timeout'),
    fields: [
      {
        key: 'read_timeout',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Integer values required.')]: integer
        }
      }
    ]
  },
  realms: ({ realms = [] } = {}) => {
    return {
      label: i18n.t('Associated Realms'),
      text: i18n.t('Realms that will be associated with this source'),
      fields: [
        {
          key: 'realms',
          component: pfFormChosen,
          attrs: {
            collapseObject: true,
            placeholder: i18n.t('Click to add a realm'),
            trackBy: 'value',
            label: 'text',
            multiple: true,
            clearOnSelect: false,
            closeOnSelect: false,
            options: realms.map(realm => { return { value: realm.id.toLowerCase(), text: realm.id.toLowerCase() } })
          }
        }
      ]
    }
  },
  redirect_url: {
    label: i18n.t('Portal URL'),
    text: i18n.t('The hostname must be the one of your captive portal.'),
    fields: [
      {
        key: 'redirect_url',
        component: pfFormInput,
        validators: {
          [i18n.t('URL required.')]: required
        }
      }
    ]
  },
  reject_realm: ({ realms = [] } = {}) => {
    return {
      label: i18n.t('Reject Realms'),
      text: i18n.t('Realms that will be rejected'),
      fields: [
        {
          key: 'reject_realm',
          component: pfFormChosen,
          attrs: {
            collapseObject: true,
            placeholder: i18n.t('Click to add a realm'),
            trackBy: 'value',
            label: 'text',
            multiple: true,
            clearOnSelect: false,
            closeOnSelect: false,
            options: realms.map(realm => { return { value: realm.id.toLowerCase(), text: realm.id.toLowerCase() } })
          }
        }
      ]
    }
  },
  scope: {
    label: i18n.t('Scope'),
    fields: [
      {
        key: 'scope',
        component: pfFormSelect,
        attrs: {
          options: [
            { value: 'base', text: i18n.t('Base Object') },
            { value: 'one', text: 'One-level' },
            { value: 'sub', text: 'Subtree' },
            { value: 'children', text: 'Children' }
          ]
        },
        validators: {
          [i18n.t('Scope required.')]: required
        }
      }
    ]
  },
  secret: {
    label: i18n.t('Secret'),
    fields: [
      {
        key: 'secret',
        component: pfFormPassword,
        validators: {
          [i18n.t('Secret required.')]: required
        }
      }
    ]
  },
  secret_key: {
    label: i18n.t('Secret key'),
    fields: [
      {
        key: 'secret_key',
        component: pfFormInput
      }
    ]
  },
  send_email_confirmation: {
    label: i18n.t('Send billing confirmation'),
    fields: [
      {
        key: 'send_email_confirmation',
        component: pfFormToggle,
        attrs: {
          values: { checked: 'enabled', unchecked: 'disabled' }
        }
      }
    ]
  },
  server1_address: {
    label: i18n.t('Server 1 address'),
    text: i18n.t('Eduroam server 1 address'),
    fields: [
      {
        key: 'server1_address',
        component: pfFormInput,
        validators: {
          [i18n.t('Address required.')]: required
        }
      }
    ]
  },
  server1_port: {
    label: i18n.t('Eduroam server 1 port'),
    fields: [
      {
        key: 'server1_port',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Enter a valid port number')]: isPort
        }
      }
    ]
  },
  server2_address: {
    label: i18n.t('Server 2 address'),
    text: i18n.t('Eduroam server 1 address'),
    fields: [
      {
        key: 'server2_address',
        component: pfFormInput,
        validators: {
          [i18n.t('Address required.')]: required
        }
      }
    ]
  },
  server2_port: {
    label: i18n.t('Eduroam server 2 port'),
    fields: [
      {
        key: 'server2_port',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Enter a valid port number.')]: isPort
        }
      }
    ]
  },
  service_fqdn: {
    label: i18n.t('Service FQDN'),
    fields: [
      {
        key: 'service_fqdn',
        component: pfFormInput
      }
    ]
  },
  shared_secret: {
    label: i18n.t('Shared Secret'),
    text: i18n.t('MKEY for the iframe'),
    fields: [
      {
        key: 'shared_secret',
        component: pfFormInput,
        validators: {
          [i18n.t('Secret required.')]: required
        }
      }
    ]
  },
  shared_secret_direct: {
    label: i18n.t('Shared Secret Direct'),
    text: i18n.t('MKEY for Mirapay Direct'),
    fields: [
      {
        key: 'shared_secret_direct',
        component: pfFormInput,
        validators: {
          [i18n.t('Secret required.')]: required
        }
      }
    ]
  },
  shuffle: {
    label: i18n.t('Shuffle'),
    text: i18n.t('Randomly choose LDAP server to query'),
    fields: [
      {
        key: 'shuffle',
        component: pfFormToggle,
        attrs: {
          values: { checked: '1', unchecked: '0' }
        }
      }
    ]
  },
  site: {
    label: null, // multiple occurances w/ different strings, nullify for overload
    fields: [
      {
        key: 'site',
        component: pfFormInput,
        validators: {
          [i18n.t('URL required.')]: required
        }
      }
    ]
  },
  sms_activation_timeout: {
    label: i18n.t('SMS Activation Timeout '),
    text: i18n.t('This is the delay given to a guest who registered by SMS confirmation to fill the PIN code.'),
    fields: [
      {
        key: 'sms_activation_timeout.interval',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Interval required.')]: required,
          [i18n.t('Integer values required.')]: integer
        }
      },
      {
        key: 'sms_activation_timeout.unit',
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
        },
        validators: {
          [i18n.t('Unit required.')]: required
        }
      }
    ]
  },
  sms_carriers: {
    label: i18n.t('SMS Carriers'),
    text: i18n.t('List of phone carriers available to the user'),
    fields: [
      {
        key: 'sms_carriers',
        component: pfFormChosen,
        attrs: {
          collapseObject: true,
          placeholder: i18n.t('Click to add a carrier'),
          trackBy: 'value',
          label: 'text',
          multiple: true,
          clearOnSelect: false,
          closeOnSelect: false,
          options: [ /* TODO: replace w/ endpoint */
            { value: '100056', text: '3 River Wireless' },
            { value: '100057', text: '7-11 Speakout' },
            { value: '100061', text: 'AT&T Wireless' },
            { value: '100058', text: 'Airtel (Karnataka, India)' },
            { value: '100059', text: 'Alaska Communications Systems' },
            { value: '100060', text: 'Alltel Wireless' },
            { value: '100062', text: 'Bell Mobility (Canada)' },
            { value: '100063', text: 'Boost Mobile' },
            { value: '100071', text: 'CTI' },
            { value: '100064', text: 'Cellular One (Dobson)' },
            { value: '100116', text: 'Cellular South' },
            { value: '100066', text: 'Centennial Wireless' },
            { value: '100123', text: 'Chatr' },
            { value: '100117', text: 'ChinaMobile (139)' },
            { value: '100112', text: 'Cincinnati Bell Wireless' },
            { value: '100067', text: 'Cingular (GoPhone prepaid)' },
            { value: '100065', text: 'Cingular (Postpaid)' },
            { value: '100068', text: 'Claro (Nicaragua)' },
            { value: '100069', text: 'Comcel' },
            { value: '100070', text: 'Cricket' },
            { value: '100118', text: 'Dialog Axiata' },
            { value: '100115', text: 'E-Plus' },
            { value: '100124', text: 'Eastlink' },
            { value: '100072', text: 'Emtel (Mauritius)' },
            { value: '100073', text: 'Fido (Canada)' },
            { value: '100125', text: 'Freedom' },
            { value: '100074', text: 'General Communications Inc.' },
            { value: '100075', text: 'Globalstar' },
            { value: '100076', text: 'Helio' },
            { value: '100078', text: 'i wireless' },
            { value: '100077', text: 'Illinois Valley Cellular' },
            { value: '100122', text: 'Koodo Mobile' },
            { value: '100085', text: 'MTN (South Africa)' },
            { value: '100086', text: 'MTS (Canada)' },
            { value: '100080', text: 'Mero Mobile (Nepal)' },
            { value: '100079', text: 'Meteor (Ireland)' },
            { value: '100081', text: 'MetroPCS' },
            { value: '100083', text: 'Mobitel (Sri Lanka)' },
            { value: '100082', text: 'Movicom' },
            { value: '100084', text: 'Movistar (Colombia)' },
            { value: '100087', text: 'Nextel (Argentina)' },
            { value: '100120', text: 'Orange (CH)' },
            { value: '100088', text: 'Orange (Poland)' },
            { value: '100111', text: 'Orange (UK)' },
            { value: '100126', text: 'PC Mobile' },
            { value: '100089', text: 'Personal (Argentina)' },
            { value: '100090', text: 'Plus GSM (Poland)' },
            { value: '100091', text: 'President\'s Choice (Canada)' },
            { value: '100092', text: 'Qwest' },
            { value: '100093', text: 'Rogers (Canada)' },
            { value: '100094', text: 'Sasktel (Canada)' },
            { value: '100095', text: 'Setar Mobile email (Aruba)' },
            { value: '100096', text: 'Solo Mobile' },
            { value: '100098', text: 'Sprint (Nextel)' },
            { value: '100097', text: 'Sprint (PCS)' },
            { value: '100099', text: 'Suncom' },
            { value: '100121', text: 'Sunrise' },
            { value: '100119', text: 'Swisscom' },
            { value: '100100', text: 'T-Mobile' },
            { value: '100101', text: 'T-Mobile (Austria)' },
            { value: '100113', text: 'T-Mobile Germany' },
            { value: '100127', text: 'TBayTel' },
            { value: '100102', text: 'Telus Mobility (Canada)' },
            { value: '100103', text: 'Thumb Cellular' },
            { value: '100104', text: 'Tigo (Formerly Ola)' },
            { value: '100106', text: 'US Cellular' },
            { value: '100105', text: 'Unicel' },
            { value: '100107', text: 'Verizon' },
            { value: '100108', text: 'Virgin Mobile (Canada)' },
            { value: '100109', text: 'Virgin Mobile (USA)' },
            { value: '100114', text: 'Vodafone Germany' },
            { value: '100110', text: 'YCC' }
          ]
        }
      }
    ]
  },
  sp_cert_path: {
    label: i18n.t('Path to Service Provider cert (x509)'),
    fields: [
      {
        key: 'sp_cert_path',
        component: pfFormInput,
        validators: {
          [i18n.t('Path required.')]: required
        }
      }
    ]
  },
  sp_entity_id: {
    label: i18n.t('Service Provider entity ID'),
    fields: [
      {
        key: 'sp_entity_id',
        component: pfFormInput,
        validators: {
          [i18n.t('ID required.')]: required
        }
      }
    ]
  },
  sp_key_path: {
    label: i18n.t('Path to Service Provider key (x509)'),
    fields: [
      {
        key: 'sp_key_path',
        component: pfFormInput,
        validators: {
          [i18n.t('Path required.')]: required
        }
      }
    ]
  },
  sponsorship_bcc: {
    label: i18n.t('Sponsorship BCC'),
    text: i18n.t('Sponsors requesting access and access confirmation emails are BCC\'ed to this address. Multiple destinations can be comma separated.'),
    fields: [
      {
        key: 'sponsorship_bcc',
        component: pfFormInput,
        validators: {
          [i18n.t('Path required.')]: required
        }
      }
    ]
  },
  style: {
    label: i18n.t('Style'),
    fields: [
      {
        key: 'style',
        component: pfFormSelect,
        attrs: {
          options: [
            { value: 'charge', text: 'Charge' },
            { value: 'subscription', text: 'Subscription' }
          ]
        }
      }
    ]
  },
  terminal_id: {
    label: i18n.t('Terminal ID'),
    text: i18n.t('Terminal ID for Mirapay Direct'),
    fields: [
      {
        key: 'terminal_id',
        component: pfFormInput,
        validators: {
          [i18n.t('ID required.')]: required
        }
      }
    ]
  },
  terminal_group_id: {
    label: i18n.t('Terminal Group ID'),
    text: i18n.t('Terminal Group ID for Mirapay Direct'),
    fields: [
      {
        key: 'terminal_group_id',
        component: pfFormInput
      }
    ]
  },
  test_mode: {
    label: i18n.t('Test mode'),
    fields: [
      {
        key: 'test_mode',
        component: pfFormToggle,
        attrs: {
          values: { checked: '1', unchecked: '0' }
        }
      }
    ]
  },
  timeout: {
    label: i18n.t('Timeout'),
    fields: [
      {
        key: 'timeout',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Timeout required.')]: required,
          [i18n.t('Integer values required.')]: integer
        }
      }
    ]
  },
  transaction_key: {
    label: i18n.t('Transaction key'),
    fields: [
      {
        key: 'transaction_key',
        component: pfFormInput,
        validators: {
          [i18n.t('Timeout required.')]: required
        }
      }
    ]
  },
  twilio_phone_number: {
    label: i18n.t('Phone Number (From)'),
    text: i18n.t('Twilio provided phone number which will show as the sender'),
    fields: [
      {
        key: 'twilio_phone_number',
        component: pfFormInput,
        attrs: {
          placeholder: '+15555551234'
        },
        validators: {
          [i18n.t('Phone number required.')]: required
        }
      }
    ]
  },
  user_header: {
    label: i18n.t('User header '),
    fields: [
      {
        key: 'user_header',
        component: pfFormInput,
        validators: {
          [i18n.t('Header required.')]: required
        }
      }
    ]
  },
  username_attribute: {
    label: i18n.t('Attribute of the username in the SAML response'),
    fields: [
      {
        key: 'username_attribute',
        component: pfFormInput
      }
    ]
  },
  usernameattribute: {
    label: i18n.t('Username Attribute'),
    fields: [
      {
        key: 'usernameattribute',
        component: pfFormInput,
        validators: {
          [i18n.t('Username Attribute required.')]: required
        }
      }
    ]
  },
  validate_sponsor: {
    label: i18n.t('Sponsor Validation'),
    text: i18n.t('Force sponsor to authenticate when validating a guest request.'),
    fields: [
      {
        key: 'validate_sponsor',
        component: pfFormToggle,
        attrs: {
          values: { checked: 'yes', unchecked: 'no' }
        }
      }
    ]
  },
  write_timeout: {
    label: i18n.t('Request timeout'),
    text: i18n.t('LDAP request timeout'),
    fields: [
      {
        key: 'write_timeout',
        component: pfFormInput,
        attrs: {
          type: 'number'
        },
        validators: {
          [i18n.t('Integer values required.')]: integer
        }
      }
    ]
  }
}

export const pfConfigurationAuthenticationSourcesViewFields = (context) => {
  const { sourceType = null } = context
  switch (sourceType) {
    case 'AD':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.host_port_encryption,
        pfConfigurationViewFields.connection_timeout,
        pfConfigurationViewFields.write_timeout,
        pfConfigurationViewFields.read_timeout,
        pfConfigurationViewFields.basedn,
        pfConfigurationViewFields.scope,
        pfConfigurationViewFields.usernameattribute,
        pfConfigurationViewFields.email_attribute,
        pfConfigurationViewFields.binddn,
        pfConfigurationViewFields.password(context),
        pfConfigurationViewFields.cache_match,
        pfConfigurationViewFields.monitor,
        pfConfigurationViewFields.shuffle,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'EAPTLS':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'Htpasswd':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.path,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'HTTP':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.protocol_ip_port,
        pfConfigurationViewFields.api_username,
        pfConfigurationViewFields.api_password,
        pfConfigurationViewFields.authentication_url,
        pfConfigurationViewFields.authorization_url,
        pfConfigurationViewFields.realms(context)
      ]
    case 'Kerberos':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.host,
        pfConfigurationViewFields.authenticate_realm,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'LDAP':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.host_port_encryption,
        pfConfigurationViewFields.connection_timeout,
        pfConfigurationViewFields.write_timeout,
        pfConfigurationViewFields.read_timeout,
        pfConfigurationViewFields.basedn,
        pfConfigurationViewFields.scope,
        pfConfigurationViewFields.usernameattribute,
        pfConfigurationViewFields.email_attribute,
        pfConfigurationViewFields.binddn,
        pfConfigurationViewFields.password(context),
        pfConfigurationViewFields.cache_match,
        pfConfigurationViewFields.monitor,
        pfConfigurationViewFields.shuffle,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'POTD':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.password_rotation,
        pfConfigurationViewFields.password_email_update,
        pfConfigurationViewFields.password_length,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'RADIUS':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.host,
        pfConfigurationViewFields.secret,
        pfConfigurationViewFields.timeout,
        pfConfigurationViewFields.monitor,
        pfConfigurationViewFields.realms(context),
        pfConfigurationViewFields.authentication_rules(context),
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'SAML':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.sp_entity_id,
        pfConfigurationViewFields.sp_key_path,
        pfConfigurationViewFields.idp_entity_id,
        pfConfigurationViewFields.idp_metadata_path,
        pfConfigurationViewFields.idp_cert_path,
        pfConfigurationViewFields.idp_ca_cert_path,
        pfConfigurationViewFields.username_attribute,
        pfConfigurationViewFields.authorization_source_id(context)
      ]
    case 'Email':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        Object.assign(pfConfigurationViewFields.email_activation_timeout, {
          text: i18n.t('This is the delay given to a guest who registered by email confirmation to log into his email and click the activation link.')
        }), // re-text
        pfConfigurationViewFields.allow_localdomain,
        pfConfigurationViewFields.activation_domain,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Facebook':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('Graph API URL') }), // re-label
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('Graph API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('Graph API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Github':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Google':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Instagram':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('Graph API URL') }), // re-label
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('Graph API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('Graph API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Kickbox':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.api_key,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'LinkedIn':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Null':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.email_required,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'OpenID':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Pinterest':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('Graph API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('Graph API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'SMS':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.sms_carriers,
        pfConfigurationViewFields.sms_activation_timeout,
        pfConfigurationViewFields.message,
        pfConfigurationViewFields.pin_code_length,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'SponsorEmail':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.allow_localdomain,
        Object.assign(pfConfigurationViewFields.email_activation_timeout, { text: i18n.t('Delay given to a sponsor to click the activation link.') }), // re-text
        pfConfigurationViewFields.activation_domain,
        pfConfigurationViewFields.sponsorship_bcc,
        pfConfigurationViewFields.validate_sponsor,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Twilio':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.account_sid,
        pfConfigurationViewFields.auth_token,
        pfConfigurationViewFields.twilio_phone_number,
        pfConfigurationViewFields.message,
        pfConfigurationViewFields.pin_code_length,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'Twitter':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'WindowsLive':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.client_id,
        pfConfigurationViewFields.client_secret,
        Object.assign(pfConfigurationViewFields.site, { label: i18n.t('API URL') }), // re-label
        pfConfigurationViewFields.authorize_path,
        Object.assign(pfConfigurationViewFields.access_token_path, { label: i18n.t('API Token Path') }), // re-label
        pfConfigurationViewFields.access_token_param,
        pfConfigurationViewFields.access_scope,
        Object.assign(pfConfigurationViewFields.protected_resource_url, { label: i18n.t('API URL of logged user') }), // re-label
        pfConfigurationViewFields.redirect_url,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'AdminProxy':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.proxy_addresses,
        pfConfigurationViewFields.user_header,
        pfConfigurationViewFields.group_header,
        pfConfigurationViewFields.administration_rules(context)
      ]
    case 'Blackhole':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description
      ]
    case 'Eduroam':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.server1_address,
        pfConfigurationViewFields.server1_port,
        pfConfigurationViewFields.server2_address,
        pfConfigurationViewFields.server2_port,
        pfConfigurationViewFields.radius_secret,
        pfConfigurationViewFields.auth_listening_port,
        pfConfigurationViewFields.reject_realm(context),
        pfConfigurationViewFields.local_realm(context),
        pfConfigurationViewFields.monitor,
        pfConfigurationViewFields.authentication_rules(context)
      ]
    case 'AuthorizeNet':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.api_login_id,
        pfConfigurationViewFields.transaction_key,
        pfConfigurationViewFields.public_client_key,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.currency,
        pfConfigurationViewFields.test_mode,
        pfConfigurationViewFields.send_email_confirmation,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins
      ]
    case 'Mirapay':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        { label: i18n.t('MiraPay iframe settings'), labelSize: 'lg' },
        pfConfigurationViewFields.base_url,
        pfConfigurationViewFields.merchant_id,
        pfConfigurationViewFields.shared_secret,
        { label: i18n.t('MiraPay direct settings'), labelSize: 'lg' },
        pfConfigurationViewFields.direct_base_url,
        pfConfigurationViewFields.terminal_id,
        pfConfigurationViewFields.shared_secret_direct,
        pfConfigurationViewFields.terminal_group_id,
        { label: i18n.t('Additional settings'), labelSize: 'lg' },
        pfConfigurationViewFields.service_fqdn,
        pfConfigurationViewFields.currency,
        pfConfigurationViewFields.test_mode,
        pfConfigurationViewFields.send_email_confirmation,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins
      ]
    case 'Paypal':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.currency,
        pfConfigurationViewFields.send_email_confirmation,
        pfConfigurationViewFields.test_mode,
        pfConfigurationViewFields.identity_token,
        pfConfigurationViewFields.cert_id,
        pfConfigurationViewFields.cert_file,
        pfConfigurationViewFields.key_file,
        pfConfigurationViewFields.paypal_cert_file,
        pfConfigurationViewFields.email_address,
        pfConfigurationViewFields.payment_type,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins
      ]
    case 'Stripe':
      return [
        pfConfigurationViewFields.id(context),
        pfConfigurationViewFields.description,
        pfConfigurationViewFields.currency,
        pfConfigurationViewFields.send_email_confirmation,
        pfConfigurationViewFields.test_mode,
        pfConfigurationViewFields.secret_key,
        pfConfigurationViewFields.publishable_key,
        pfConfigurationViewFields.style,
        pfConfigurationViewFields.domains,
        pfConfigurationViewFields.create_local_account,
        pfConfigurationViewFields.local_account_logins
      ]
    default:
      return []
  }
}

export const pfConfigurationDomainsViewFields = (context = {}) => {
  const { isNew = false, isClone = false } = context
  return [
    {
      label: i18n.t('Identifier'),
      text: i18n.t('Specify a unique identifier for your configuration.<br/>This doesn\'t have to be related to your domain.'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew && !isClone)
          },
          validators: {
            [i18n.t('Name required.')]: required,
            [i18n.t('Alphanumeric characters only.')]: alphaNum
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
            [i18n.t('Workgroup required.')]: required
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
            [i18n.t('DNS name required.')]: required,
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
            [i18n.t('Server name required.')]: required
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
            [i18n.t('Sticky DC required.')]: required
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
            [i18n.t('Active Directory server required.')]: required
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

export const pfConfigurationFloatingDevicesViewFields = (context = {}) => {
  const { isNew = false, isClone = false } = context
  return [
    {
      label: i18n.t('MAC Address'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew && !isClone)
          },
          validators: {
            [i18n.t('MAC address required.')]: required,
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
            [i18n.t('IP address required.')]: required,
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
            [i18n.t('Native VLAN required.')]: required,
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

export const pfConfigurationPortalModuleViewFields = (context = {}) => {
  return []
}

export const pfConfigurationRealmViewFields = (context = {}) => {
  const { isNew = false, isClone = false, domains = [] } = context
  return [
    {
      label: i18n.t('Realm'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew && !isClone)
          },
          validators: {
            [i18n.t('Realm required.')]: required,
            [i18n.t('Alphanumeric characters only.')]: alphaNum
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
      text: i18n.t('Should the usernames matching this realm be stripped when used in the authorization phase of 802.1x.' +
        ' Note that this doesn\'t control the stripping in FreeRADIUS, use the options above for that.'),
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

export const pfConfigurationBillingTierViewFields = (context = {}) => {
  const { isNew = false, isClone = false } = context
  return [
    {
      label: i18n.t('Billing Tier'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            disabled: (!isNew && !isClone)
          },
          validators: {
            [i18n.t('Name required.')]: required,
            [i18n.t('Alphanumeric characters only.')]: alphaNum
          }
        }
      ]
    },
    {
      label: i18n.t('Name'),
      fields: [
        {
          key: 'name',
          component: pfFormInput
        }
      ]
    },
    pfConfigurationViewFields.description,
    {
      label: i18n.t('Price'),
      text: i18n.t('The price that will be charged to the customer.'),
      fields: [
        {
          key: 'price',
          component: pfFormInput,
          attrs: {
            type: 'number',
            step: '0.01',
            formatter: (value) => {
              return parseFloat(value).toFixed(2)
            }
          },
          validators: {
            [i18n.t('Price required')]: required,
            [i18n.t('Enter a valid price')]: isPrice,
            [i18n.t('Enter a positive price')]: minValue(0)
          }
        }
      ]
    },
    {
      label: i18n.t('Role'),
      text: i18n.t('The target role of the devices that use this tier.'),
      fields: [
        {
          key: 'role',
          component: pfFormChosen,
          attrs: {
            collapseObject: true,
            placeholder: i18n.t('Click to select a role'),
            trackBy: 'value',
            label: 'text',
            options: context.roles.map(role => { return { value: role.name, text: role.name } })
          },
          validators: {
            [i18n.t('Role required.')]: required
          }
        }
      ]
    },
    {
      label: i18n.t('Access Duration'),
      text: null, // multiple occurances w/ different strings, nullify for overload
      fields: [
        {
          key: 'access_duration.interval',
          component: pfFormInput,
          attrs: {
            type: 'number'
          },
          validators: {
            [i18n.t('Interval required.')]: required,
            [i18n.t('Integer values required.')]: integer
          }
        },
        {
          key: 'access_duration.unit',
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
          },
          validators: {
            [i18n.t('Units required.')]: required
          }
        }
      ]
    },
    {
      label: i18n.t('Use Time Balance'),
      text: i18n.t('Check this box to have the access duration be a real time usage.<br/>This requires a working accounting configuration.'),
      fields: [
        {
          key: 'use_time_balance',
          component: pfFormToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    },
  ]
}

export const pfConfigurationRoleViewFields = (context = {}) => {
  const { isNew = false, isClone = false } = context
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
            [i18n.t('Name required.')]: required,
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
    }
  ]
}

export const pfConfigurationAuthenticationSourcesViewDefaults = (context = {}) => {
  const { sourceType = null } = context
  switch (sourceType) {
    case 'AD':
      return {
        id: null,
        port: '389',
        encryption: 'none',
        connection_timeout: '1',
        write_timeout: '5',
        read_timeout: '10',
        scope: 'sub',
        usernameattribute: 'sAMAccountName',
        email_attribute: 'mail',
        cache_match: '1',
        authentication_rules: [],
        administration_rules: []
      }
    case 'HTTP':
      return {
        protocol: 'http',
        ip: '127.0.0.1',
        port: '10000'
      }
    case 'LDAP':
      return {
        id: null,
        port: '389',
        encryption: 'none',
        connection_timeout: '1',
        write_timeout: '5',
        read_timeout: '10',
        scope: 'sub',
        email_attribute: 'mail',
        monitor: '1'
      }
    case 'POTD':
      return {
        'password_rotation.interval': '10',
        'password_rotation.unit': 'm',
        password_length: '8'
      }
    case 'RADIUS':
      return {
        host: '127.0.0.1',
        port: '1812',
        timeout: '1'
      }
    case 'SAML':
      return {
        username_attribute: 'urn:oid:0.9.2342.19200300.100.1.1',
        authorization_source_id: 'local'
      }
    case 'Email':
      return {
        'email_activation_timeout.interval': '10',
        'email_activation_timeout.unit': 'm',
        allow_localdomain: 'yes',
        local_account_logins: '0'
      }
    case 'Facebook':
      return {
        site: 'https://graph.facebook.com',
        access_token_path: '/oauth/access_token',
        access_token_param: 'access_token',
        scope: 'email',
        protected_resource_url: 'https://graph.facebook.com/me?fields=id,name,email,first_name,last_name',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.facebook.com,*.fbcdn.net,*.akamaihd.net,*.akamaiedge.net,*.edgekey.net,*.akamai.net',
        local_account_logins: '0'
      }
    case 'Github':
      return {
        site: 'https://github.com',
        authorize_path: '/login/oauth/authorize',
        access_token_path: '/login/oauth/access_token',
        access_token_param: 'access_token',
        scope: 'user,user:email',
        protected_resource_url: 'https://api.github.com/user',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: 'api.github.com,*.github.com,github.com',
        local_account_logins: '0'
      }
    case 'Google':
      return {
        client_id: 'YOUR_API_ID.apps.googleusercontent.com',
        site: 'https://accounts.google.com',
        authorize_path: '/o/oauth2/auth',
        access_token_path: '/o/oauth2/token',
        access_token_param: 'oauth_token',
        scope: 'https://www.googleapis.com/auth/userinfo.email',
        protected_resource_url: 'https://www.googleapis.com/oauth2/v2/userinfo',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.google.com,*.gstatic.com,googleapis.com,accounts.youtube.com,*.googleusercontent.com',
        local_account_logins: '0'
      }
    case 'Instagram':
      return {
        site: 'https://api.instagram.com',
        access_token_path: '/oauth/access_token',
        access_token_param: 'access_token',
        scope: 'basic',
        protected_resource_url: 'https://api.instagram.com/v1/users/self/?access_token=',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.instagram.com,*.cdninstagram.com,*.fbcdn.net',
        local_account_logins: '0'
      }
    case 'LinkedIn':
      return {
        site: 'https://www.linkedin.com',
        authorize_path: '/oauth/v2/authorization',
        access_token_path: '/oauth/v2/accessToken',
        access_token_param: 'code',
        protected_resource_url: 'https://api.linkedin.com/v1/people/~/email-address',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: 'www.linkedin.com,api.linkedin.com,*.licdn.com,platform.linkedin.com',
        local_account_logins: '0'
      }
    case 'OpenID':
      return {
        scope: 'openid',
        redirect_url: 'https://<hostname>/oauth2/callback',
        local_account_logins: '0'
      }
    case 'Pinterest':
      return {
        site: 'https://api.pinterest.com',
        authorize_path: '/oauth/',
        access_token_path: '/v1/oauth/token',
        access_token_param: 'access_token',
        scope: 'read_public',
        protected_resource_url: 'https://api.pinterest.com/v1/me',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.pinterest.com,*.api.pinterest.com,*.akamaiedge.net,*.pinimg.com,*.fastlylb.net',
        local_account_logins: '0'
      }
    case 'SMS':
      return {
        sms_carriers: ['100056', '100057', '100058', '100059', '100060', '100061', '100062', '100063', '100064', '100065', '100066', '100067', '100068', '100069', '100070', '100071', '100072', '100073', '100074', '100075', '100076', '100077', '100078', '100079', '100080', '100081', '100082', '100083', '100084', '100085', '100086', '100087', '100088', '100089', '100090', '100091', '100092', '100093', '100094', '100095', '100096', '100097', '100098', '100099', '100100', '100101', '100102', '100103', '100104', '100105', '100106', '100107', '100108', '100109', '100110', '100111', '100112', '100113', '100114', '100115', '100116', '100117', '100118', '100119', '100120', '100121', '100122', '100123', '100124', '100125', '100126', '100127'],
        'sms_activation_timeout.interval': '10',
        'sms_activation_timeout.unit': 'm',
        'message': 'PIN: $pin',
        pin_code_length: '6',
        local_account_logins: '0'
      }
    case 'SponsorEmail':
      return {
        allow_localdomain: 'yes',
        'email_activation_timeout.interval': '30',
        'email_activation_timeout.unit': 'm',
        validate_sponsor: 'yes',
        local_account_logins: '0'
      }
    case 'Twilio':
      return {
        pin_code_length: '6',
        local_account_logins: '0'
      }
    case 'Twitter':
      return {
        client_id: '<CONSUMER KEY>',
        site: 'https://api.twitter.com',
        authorize_path: '/oauth/authenticate',
        access_token_path: '/oauth/request_token',
        protected_resource_url: 'https://api.twitter.com/oauth/access_token',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: '*.twitter.com,twitter.com,*.twimg.com,twimg.com'
      }
    case 'WindowsLive':
      return {
        site: 'https://login.live.com',
        authorize_path: '/oauth20_authorize.srf',
        access_token_path: '/oauth20_token.srf',
        access_token_param: 'oauth_token',
        scope: 'wl.basic,wl.emails',
        protected_resource_url: 'https://apis.live.net/v5.0/me',
        redirect_url: 'https://<hostname>/oauth2/callback',
        domains: 'login.live.com,auth.gfx.ms,account.live.com',
        local_account_logins: '0'
      }
    case 'Eduroam':
      return {
        server1_port: '1812',
        server2_port: '1812',
        auth_listening_port: '11812',
        monitor: '1'
      }
    case 'AuthorizeNet':
      return {
        domains: '*.authorize.net',
        currency: 'USD',
        local_account_logins: '0'
      }
    case 'Mirapay':
      return {
        base_url: 'https://staging.eigendev.com/MiraSecure/GetToken.php',
        direct_base_url: 'https://staging.eigendev.com/OFT/EigenOFT_d.php',
        service_fqdn: 'packetfence.satkunas.com', /* TODO: build fqdn dynamically */
        currency: 'USD',
        local_account_logins: '0'
      }
    case 'Paypal':
      return {
        currency: 'USD',
        payment_type: '_xclick',
        domains: '*.paypal.com,*.paypalobjects.com',
        local_account_logins: '0'
      }
    case 'Stripe':
      return {
        currency: 'USD',
        style: 'charge',
        domains: '*.stripe.com',
        local_account_logins: '0'
      }
    case 'EAPTLS':
    case 'Htpasswd':
    case 'Kerberos':
    case 'Null':
    case 'AdminProxy':
    case 'Blackhole':
    default:
      return {}
  }
}

export const pfConfigurationBillingTierViewDefaults = (context = {}) => {
  return {
    id: null
  }
}

export const pfConfigurationDomainsViewDefaults = (context = {}) => {
  return {
    id: null,
    ad_server: '%h'
  }
}

export const pfConfigurationFloatingDevicesViewDefaults = (context = {}) => {
  return {
    id: null
  }
}

export const pfConfigurationPortalModuleViewDefaults = (context = {}) => {
  return {
    id: null
  }
}

export const pfConfigurationRealmViewDefaults = (context = {}) => {
  return {
    id: null,
    portal_strip_username: 'enabled',
    admin_strip_username: 'enabled',
    radius_strip_username: 'enabled'
  }
}

export const pfConfigurationRoleViewDefaults = (context = {}) => {
  return {
    id: null
  }
}

