import i18n from '@/utils/locale'
import bytes from '@/utils/bytes'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormToggle from '@/components/pfFormToggle'
import { pfAuthenticationConditionType as authenticationConditionType } from '@/globals/pfAuthenticationConditions'
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  alphaNum,
  and,
  not,
  conditional,
  compareDate,
  isDateFormat,
  hasSources,
  sourceExists,
  requireAllSiblingFields,
  requireAnySiblingFields,
  restrictAllSiblingFields,
  limitSiblingFields
} from '@/globals/pfValidators'

const {
  integer,
  minLength,
  maxLength,
  maxValue,
  minValue,
  numeric,
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationValidatorsFromMeta = (meta = {}, fieldName = 'Value') => {
  let validators = {}
  Object.keys(meta).forEach(key => {
    switch (key) {
      case 'min_value':
        validators = { ...validators, ...{ [i18n.t('Minimum {minValue}.', { minValue: meta[key] })]: minValue(meta[key]) } }
        break
      case 'max_value':
        validators = { ...validators, ...{ [i18n.t('Maximum {maxValue}.', { maxValue: meta[key] })]: maxValue(meta[key]) } }
        break
      case 'min_length':
        validators = { ...validators, ...{ [i18n.t('Minimum {minLength} characters.', { minLength: meta[key] })]: minLength(meta[key]) } }
        break
      case 'max_length':
        validators = { ...validators, ...{ [i18n.t('Maximum {minLength} characters.', { maxLength: meta[key] })]: maxLength(meta[key]) } }
        break
      case 'required':
        if (meta[key]) {
          validators = { ...validators, ...{ [i18n.t('{fieldName} required.', { fieldName: fieldName })]: required } }
        }
        break
      case 'type':
        switch (meta[key]) {
          case 'integer':
            validators = { ...validators, ...{ [i18n.t('Integers only.')]: integer } }
            break
          case 'array': // ignore
          case 'string': // ignore
            break
          default:
            throw new Error(`Unhandled meta type: ${meta[key]}`) // TODO: remove post-devel
            // break
        }
        break
      default:
        throw new Error(`Unhandled meta: ${key}`) // TODO: remove post-devel
        // break
    }
  })
  return validators
}

export const pfConfigurationLocales = [
  'en_US',
  'de_DE',
  'es_ES',
  'fr_CA',
  'fr_FR',
  'he_IL',
  'it_IT',
  'nl_NL',
  'pl_PL',
  'pt_BR'
].map(locale => { return { text: locale, value: locale } })

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
    types: [fieldType.TIME_BALANCE],
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
  ntlm_cache: {
    key: 'ntlm_cache',
    label: i18n.t('NTLM Cache'),
    sortable: true,
    visible: true
  },
  port: {
    key: 'port',
    label: i18n.t('Port'),
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
  status: {
    key: 'status',
    label: i18n.t('Status'),
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
  port: {
    value: 'port',
    text: i18n.t('Port'),
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
            [i18n.t('Maximum 255 characters.')]: maxLength(255),
            [i18n.t('Alphanumeric characters only.')]: alphaNum,
            [i18n.t('Source exists.')]: not(and(required, conditional(isNew || isClone), hasSources, sourceExists))
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
  pid_field: {
    label: i18n.t('PID field'),
    text: i18n.t('Which field should be used as the PID.'),
    fields: [
      {
        key: 'pid_field',
        component: pfFormSelect,
        attrs: {
          options: Object.keys(schema.person)
        },
        validators: {
          [i18n.t('PID field required.')]: required
        }
      }
    ]
  },
  show_first_module_on_default: {
    label: i18n.t('Show first module when none is selected'),
    fields: [
      {
        key: 'shuffle',
        component: pfFormToggle,
        attrs: {
          values: { checked: 'enabled', unchecked: 'disabled' }
        }
      }
    ]
  },
  template: {
    label: i18n.t('Template'),
    fields: [
      {
        key: 'template',
        component: pfFormInput
      }
    ]
  }
}
