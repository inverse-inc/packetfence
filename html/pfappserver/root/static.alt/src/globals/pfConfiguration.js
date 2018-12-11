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
// import { pfRegExp as regExp } from '@/globals/pfRegExp'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  compareDate,
  isDateFormat,
  // isFQDN,
  isPort,
  // isPrice,
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
  // macAddress,
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
  group: {
    key: 'group',
    label: i18n.t('Group'),
    sortable: true,
    visible: true,
    formatter: (value, key, item) => {
      if (!value) item.group = i18n.t('default')
    }
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
  mode: {
    key: 'mode',
    label: i18n.t('Mode'),
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
  mode: {
    value: 'mode',
    text: i18n.t('Mode'),
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
