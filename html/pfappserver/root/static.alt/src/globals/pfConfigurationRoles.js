import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/pfConfiguration'
import {
  and,
  not,
  conditional,
  roleExists
} from '@/globals/pfValidators'

const {
  integer,
  required,
  alphaNum,
  maxLength
} = require('vuelidate/lib/validators')

export const pfConfigurationRolesListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Name') }), // re-label
  pfConfigurationListColumns.notes,
  pfConfigurationListColumns.max_nodes_per_pid,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationRolesListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Name') }), // re-text
  pfConfigurationListFields.notes
]

export const pfConfigurationRoleViewFields = (context = {}) => {
  const { isNew = false, isClone = false } = context
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
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Name required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Alphanumeric value required.')]: alphaNum,
                [i18n.t('Role exists.')]: not(and(required, conditional(isNew || isClone), roleExists))
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
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
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
              attrs: {
                type: 'number'
              },
              validators: {
                [i18n.t('Max nodes per user required.')]: required,
                [i18n.t('Integer value required.')]: integer
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationRoleViewDefaults = (context = {}) => {
  return {
    id: null
  }
}
