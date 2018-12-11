import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormToggle from '@/components/pfFormToggle'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields,
  pfConfigurationViewFields
} from '@/globals/pfConfiguration'
import {
  isPrice
} from '@/globals/pfValidators'

const {
  required,
  alphaNum,
  integer,
  minValue
} = require('vuelidate/lib/validators')

export const pfConfigurationBillingTiersListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Identifier') }), // re-label
  pfConfigurationListColumns.name,
  pfConfigurationListColumns.price
]

export const pfConfigurationBillingTiersListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Identifier') }), // re-text
  pfConfigurationListFields.description
]

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
    }
  ]
}

export const pfConfigurationBillingTierViewDefaults = (context = {}) => {
  return {
    id: null
  }
}
