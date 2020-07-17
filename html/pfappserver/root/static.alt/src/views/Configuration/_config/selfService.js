import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasSelfServices,
  selfServiceExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: 'Identifier', // i18n defer
    required: true,
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
      return { name: 'self_service', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/self_services',
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
      defaultRoute: { name: 'self_services' }
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

export const view = (_, meta = {}) => {
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
          label: i18n.t('Status Page'),
          labelSize: 'lg'
        },
        {
          label: i18n.t('Allowed roles'),
          text: i18n.t('The list of roles that are allowed to unregister devices using the self-service portal. Leaving this empty will allow all users to unregister their devices.'),
          cols: [
            {
              namespace: 'roles_allowed_to_unregister',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'roles_allowed_to_unregister')
            }
          ]
        },
        {
          label: i18n.t('Self Service'),
          labelSize: 'lg'
        },
        {
          label: i18n.t('Role to assign'),
          text: i18n.t('The role to assign to devices registered from the self-service portal. If none is specified, the role of the registrant is used. If multiples are defined then the user will have to choose.'),
          cols: [
            {
              namespace: 'device_registration_roles',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'device_registration_roles')
            }
          ]
        },
        {
          label: i18n.t('Access duration to assign'),
          text: i18n.t(`The access duration to assign to devices registered from the self-service portal. If zero is specified, the access duration of the registrant is used.`),
          cols: [
            {
              namespace: 'device_registration_access_duration.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'device_registration_access_duration.interval')
            },
            {
              namespace: 'device_registration_access_duration.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'device_registration_access_duration.unit')
            }
          ]
        },
        {
          label: i18n.t('Allowed OS'),
          text: i18n.t('List of OS which will be allowed to be register via the self service portal.'),
          cols: [
            {
              namespace: 'device_registration_allowed_devices',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'device_registration_allowed_devices')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (_, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
      ...{
        [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasSelfServices, selfServiceExists))
      }
    },
    description: validatorsFromMeta(meta, 'description', i18n.t('Description')),
    roles_allowed_to_unregister: validatorsFromMeta(meta, 'roles_allowed_to_unregister', i18n.t('Allowed roles')),
    device_registration_roles: validatorsFromMeta(meta, 'device_registration_roles', i18n.t('Role to assign')),
    device_registration_access_duration: {
      interval: validatorsFromMeta(meta, 'device_registration_access_duration.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'device_registration_access_duration.unit', i18n.t('Unit'))
    },
    device_registration_allowed_devices: validatorsFromMeta(meta, 'device_registration_allowed_devices', 'OS')
  }
}
