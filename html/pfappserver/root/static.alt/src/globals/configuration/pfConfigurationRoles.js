import i18n from '@/utils/locale'
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
  hasRoles,
  roleExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationRolesListColumns = [
  {
    key: 'id',
    label: i18n.t('Name'),
    sortable: true,
    visible: true
  },
  {
    key: 'notes',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  {
    key: 'max_nodes_per_pid',
    label: i18n.t('Max nodes per user'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    sortable: false,
    visible: true,
    locked: true
  }
]

export const pfConfigurationRolesListFields = [
  {
    value: 'id',
    text: i18n.t('Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'notes',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationRoleListConfig = (context = {}) => {
  return {
    columns: pfConfigurationRolesListColumns,
    fields: pfConfigurationRolesListFields,
    rowClickRoute (item, index) {
      return { name: 'role', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/roles',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'notes', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'roles' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'notes', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationRoleViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    options: {
      meta = {}
    }
  } = context

  return [
    {
      tab: null, // ignore tabs
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
                ...pfConfigurationValidatorsFromMeta(meta, 'id', 'Name'),
                ...{
                  [i18n.t('Role exists.')]: not(and(required, conditional(isNew || isClone), hasRoles, roleExists))
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
          fields: [
            {
              key: 'notes',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'notes'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'notes', 'Description')
            }
          ]
        },
        {
          label: i18n.t('Max nodes per user'),
          text: i18n.t('The maximum number of nodes a user having this role can register. A number of 0 means unlimited number of devices.'),
          fields: [
            {
              key: 'max_nodes_per_pid',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'max_nodes_per_pid'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'max_nodes_per_pid', 'Max')
            }
          ]
        }
      ]
    }
  ]
}
