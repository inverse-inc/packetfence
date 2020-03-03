/* eslint-disable camelcase */
import i18n from '@/utils/locale'
import pfFieldApiMethodParameters from '@/components/pfFieldApiMethodParameters'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfFieldType as fieldType } from '@/globals/pfField'

export const columns = [
  {
    key: 'status',
    label: i18n.t('Enabled'),
    sortable: true,
    visible: true
  },
  {
    key: 'id',
    label: i18n.t('Name'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'role',
    label: i18n.t('Role'),
    sortable: true,
    visible: true
  },
  {
    key: 'scopes',
    label: i18n.t('Scopes'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

const actionsFieldsFromMeta = (meta = {}) => {
  const { actions: { item: { properties: { api_method: { allowed = [] } = {} } = {} } = {} } = {} } = meta
  return allowed.map(allowed => {
    const { text, value } = allowed
    return { text, value, types: [fieldType.SUBSTRING] }
  })
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Name'),
          text: i18n.t('Specify a unique name for your fitler.'),
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
          label: i18n.t('Enabled'),
          cols: [
            {
              namespace: 'status',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Role'),
          cols: [
            {
              namespace: 'role',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'role')
            }
          ]
        },
        {
          label: i18n.t('Scopes'),
          cols: [
            {
              namespace: 'scopes',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'scopes')
            }
          ]
        },
        {
          label: i18n.t('Actions'),
          text: i18n.t('Specify actions when codition is met.'),
          cols: [
            {
              namespace: 'actions',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Action'),
                sortable: false,
                field: {
                  component: pfFieldApiMethodParameters,
                  attrs: {
                    typeLabel: i18n.t('Select condition type'),
                    valueLabel: i18n.t('Select condition value'),
                    fields: actionsFieldsFromMeta(meta)
                  }
                },
                invalidFeedback: i18n.t('Inline Conditions contain one or more errors.')
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'Name'),
      ...{
        // [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasDomains, domainExists))
      }
    },
    role: validatorsFromMeta(meta, 'role', i18n.t('Role')),
    scopes: validatorsFromMeta(meta, 'scopes', i18n.t('Scopes'))
  }
}
