import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormToggle from '@/components/pfFormToggle'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields,
  pfConfigurationViewFields
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  not,
  conditional,
  isPrice,
  billingTierExists
} from '@/globals/pfValidators'

const {
  required,
  alphaNum,
  integer,
  minValue,
  maxLength
} = require('vuelidate/lib/validators')

export const pfConfigurationBillingTiersListColumns = [
  { ...pfConfigurationListColumns.id, ...{ label: i18n.t('Identifier') } }, // re-label
  pfConfigurationListColumns.name,
  pfConfigurationListColumns.price,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationBillingTiersListFields = [
  { ...pfConfigurationListFields.id, ...{ text: i18n.t('Identifier') } }, // re-text
  pfConfigurationListFields.description
]

export const pfConfigurationBillingTiersListConfig = (context = {}) => {
  const { $i18n } = context
  return {
    columns: pfConfigurationBillingTiersListColumns,
    fields: pfConfigurationBillingTiersListFields,
    rowClickRoute (item, index) {
      return { name: 'billing_tier', params: { id: item.id } }
    },
    searchPlaceholder: $i18n.t('Search by identifier, name or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/billing_tiers',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'name', op: 'contains', value: null },
            { field: 'description', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'billing_tiers' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'name', op: 'contains', value: quickCondition },
              { field: 'description', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationBillingTierViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    roles = []
  } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
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
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Alphanumeric characters only.')]: alphaNum,
                [i18n.t('Billing Tier exists.')]: not(and(required, conditional(isNew || isClone), billingTierExists))
              }
            }
          ]
        },
        {
          label: i18n.t('Name'),
          fields: [
            {
              key: 'name',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
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
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
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
                options: roles.map(role => { return { value: role.name, text: role.name } })
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
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
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
        }
      ]
    }
  ]
}

export const pfConfigurationBillingTierViewDefaults = (context = {}) => {
  return {
    id: null
  }
}
