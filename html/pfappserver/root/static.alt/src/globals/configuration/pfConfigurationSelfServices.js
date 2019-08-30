import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
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
  hasSelfServices,
  selfServiceExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationSelfServicesListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
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

export const pfConfigurationSelfServicesListFields = [
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

export const pfConfigurationSelfServicesListConfig = (context = {}) => {
  const { $i18n } = context
  return {
    columns: pfConfigurationSelfServicesListColumns,
    fields: pfConfigurationSelfServicesListFields,
    rowClickRoute (item, index) {
      return { name: 'self_service', params: { id: item.id } }
    },
    searchPlaceholder: $i18n.t('Search by identifier or description'),
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

export const pfConfigurationSelfServiceViewFields = (context = {}) => {
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
          label: i18n.t('Profile Name'),
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
                  [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasSelfServices, selfServiceExists))
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
        { label: i18n.t('Status Page'), labelSize: 'lg' },
        {
          label: i18n.t('Allowed roles'),
          text: i18n.t('The list of roles that are allowed to unregister devices using the self-service portal. Leaving this empty will allow all users to unregister their devices.'),
          fields: [
            {
              key: 'roles_allowed_to_unregister',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'roles_allowed_to_unregister'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'roles_allowed_to_unregister', i18n.t('Allowed roles'))
            }
          ]
        },
        { label: i18n.t('Self Service'), labelSize: 'lg' },
        {
          label: i18n.t('Role to assign'),
          text: i18n.t('The role to assign to devices registered from the self-service portal. If none is specified, the role of the registrant is used.'),
          fields: [
            {
              key: 'device_registration_role',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'device_registration_role'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'device_registration_role', i18n.t('Role to assign'))
            }
          ]
        },
        {
          label: i18n.t('Access duration to assign'),
          text: i18n.t(`The access duration to assign to devices registered from the self-service portal. If zero is specified, the access duration of the registrant is used.`),
          fields: [
            {
              key: 'device_registration_access_duration.interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'device_registration_access_duration.interval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'device_registration_access_duration.interval', i18n.t('Interval'))
            },
            {
              key: 'device_registration_access_duration.unit',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'device_registration_access_duration.unit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'device_registration_access_duration.unit', i18n.t('Unit'))
            }
          ]
        },
        {
          label: i18n.t('Allowed OS'),
          text: i18n.t('List of OS which will be allowed to be register via the self service portal.'),
          fields: [
            {
              key: 'device_registration_allowed_devices',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'device_registration_allowed_devices'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'device_registration_allowed_devices', 'OS')
            }
          ]
        }
      ]
    }
  ]
}
