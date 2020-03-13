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
import {
  required
} from 'vuelidate/lib/validators'

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
    key: 'description',
    label: i18n.t('Description'),
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
    const { text, value, sibling } = allowed
    return { text, value, sibling, types: [fieldType.SUBSTRING] }
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
          label: i18n.t('Description'),
          cols: [
            {
              namespace: 'description',
              component: pfFormInput
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
                }),
                invalidFeedback: i18n.t('Condition contains one or more errors.')
              }
            }
          ]
        },
        {
          label: i18n.t('Peform Actions'),
          text: i18n.t('Enable to perform the following actions. Disable to only apply the role.'),
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
                invalidFeedback: i18n.t('Actions contain one or more errors.')
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
        }
      ]
    }
  ]
}

const conditionValidator = (meta = {}, condition = {}) => {
  const { field, op, value, values } = condition
  if (values && values.constructor === Array) { // op
    return {
      op: {
        [i18n.t('Operator required.')]: required,
        [i18n.t('Minimum 2 values required.')]: conditional(values.length >= 2)
      },
      values: {
        ...(values || []).map(value => conditionValidator(meta, value))
      }
    }
  } else { // value
    return {
      field: {
        [i18n.t('Field required.')]: required
      },
      op: {
        [i18n.t('Operator required.')]: required
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  }
}

export const validators = (form = {}, meta = {}) => {
  const {
    condition = {},
    actions = [],
    run_actions,
    role
  } = form
  const {
    isNew = false,
    isClone = false,
    collection
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
      ...{
        [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasFilterEngines(collection), filterEngineExists(collection)))
      }
    },
    description: {
      [i18n.t('Description required.')]: required
    },
    role: {
      ...validatorsFromMeta(meta, 'role', i18n.t('Role')),
      ...{
        [i18n.t('Role required.')]: required
      }
    },
    scopes: validatorsFromMeta(meta, 'scopes', i18n.t('Scopes')),
    condition: conditionValidator(meta, condition),
    actions: {
      ...{
        [i18n.t('Actions required.')]: conditional(run_actions !== 'enabled' || actions.length > 0)
      },
      ...(actions || []).map((action) => {
        return {
          api_method: {
            [i18n.t('Method required.')]: required,
            [i18n.t('Duplicate method.')]: conditional(value => !value || actions.filter(action => action && action.api_method === value).length === 1)
          },
          api_parameters: {
            [i18n.t('Parameter required.')]: required
          }
        }
      })
    }
  }
}
