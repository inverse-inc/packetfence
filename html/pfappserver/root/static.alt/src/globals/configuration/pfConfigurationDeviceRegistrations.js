import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields,
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  not,
  conditional,
  hasDeviceRegistrations,
  deviceRegistrationExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationDeviceRegistrationsListColumns = [
  { ...pfConfigurationListColumns.id, ...{ label: i18n.t('Identifier') } }, // re-label
  pfConfigurationListColumns.description,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationDeviceRegistrationsListFields = [
  { ...pfConfigurationListFields.id, ...{ text: i18n.t('Identifier') } }, // re-text
  pfConfigurationListFields.description
]

export const pfConfigurationDeviceRegistrationsListConfig = (context = {}) => {
  const { $i18n } = context
  return {
    columns: pfConfigurationDeviceRegistrationsListColumns,
    fields: pfConfigurationDeviceRegistrationsListFields,
    rowClickRoute (item, index) {
      return { name: 'device_registration', params: { id: item.id } }
    },
    searchPlaceholder: $i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/device_registrations',
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
      defaultRoute: { name: 'device_registrations' }
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

export const pfConfigurationDeviceRegistrationViewFields = (context = {}) => {
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
                ...pfConfigurationValidatorsFromMeta(meta, 'id', 'Name'),
                ...{
                  [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasDeviceRegistrations, deviceRegistrationExists))
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
              validators: pfConfigurationValidatorsFromMeta(meta, 'description', 'Description')
            }
          ]
        },
        {
          label: i18n.t('Roles'),
          text: i18n.t('The role to assign to devices registered from the specific portal. If none is specified, the role of the registrant is used.'),
          fields: [
            {
              key: 'category',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'category'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'category', 'Roles')
            }
          ]
        },
        {
          label: i18n.t('OS'),
          text: i18n.t('List of OS which will be allowed to be register via the self service portal.'),
          fields: [
            {
              key: 'oses',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'oses'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'oses', 'OS')
            }
          ]
        }
      ]
    }
  ]
}
