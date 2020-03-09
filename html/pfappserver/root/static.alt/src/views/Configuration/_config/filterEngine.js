/* eslint-disable camelcase */
import i18n from '@/utils/locale'
import pfFieldApiMethodParameters from '@/components/pfFieldApiMethodParameters'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormFilterEngineCondition from '@/components/pfFormFilterEngineCondition'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfOperators } from '@/globals/pfOperators'
import {
  and,
  not,
  conditional,
  hasFilterEngines,
  filterEngineExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const columns = [
  {
    key: 'status',
    label: i18n.t('Status'),
    visible: true
  },
  {
    key: 'id',
    label: i18n.t('Name'),
    required: true,
    visible: true
  },
  {
    key: 'role',
    label: i18n.t('Role'),
    visible: true
  },
  {
    key: 'scopes',
    label: i18n.t('Scopes'),
    visible: true,
    formatter: (value) => {
      if (value && value.constructor === Array && value.length > 0) {
        return value
      }
      return null // otherwise '[]' is displayed in cell
    }
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

const valueOperatorsFromMeta = (meta = {}) => {
  const { condition: { properties: { op: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.filter(allowed => {
    const { requires = [] } = allowed
    return requires.includes('value')
  }).map(allowed => {
    const { value } = allowed
    return value
  })
}

const valuesOperatorsFromMeta = (meta = {}) => {
  const { condition: { properties: { op: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.filter(allowed => {
    const { requires = [] } = allowed
    return requires.includes('values')
  }).map(allowed => {
    const { value } = allowed
    return value
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
                values: { checked: 'enabled', unchecked: 'disabled' },
                icons: { checked: 'check', unchecked: 'times' },
                colors: { checked: 'var(--success)', unchecked: 'var(--danger)' }
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
          label: i18n.t('Condition'),
          text: i18n.t('Specify a condition to match.'),
          cols: [
            {
              namespace: 'condition',
              component: pfFormFilterEngineCondition,
              attrs: {
                valueOperators: valueOperatorsFromMeta(meta).map(value => {
                  const { [value]: text = value } = pfOperators
                  return { text, value }
                }),
                valuesOperators: valuesOperatorsFromMeta(meta).map(value => {
                  const { [value]: text = value } = pfOperators
                  return { text, value }
                })
              }
            }
          ]
        },
        {
          label: i18n.t('Peform Actions'),
          text: i18n.t('Enable to perform the following actions when the condition is met. Otherwise only the role is applied.'),
          cols: [
            {
              namespace: 'run_actions',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: form.run_actions === 'enabled',
          label: i18n.t('Actions'),
          text: i18n.t('Specify actions when condition is met.'),
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
    isClone = false,
    collection
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'Name'),
      ...{
        [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasFilterEngines(collection), filterEngineExists(collection)))
      }
    },
    role: validatorsFromMeta(meta, 'role', i18n.t('Role')),
    scopes: validatorsFromMeta(meta, 'scopes', i18n.t('Scopes'))
  }
}
