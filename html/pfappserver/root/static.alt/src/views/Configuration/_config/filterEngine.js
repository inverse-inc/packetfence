import store from '@/store'
import i18n from '@/utils/locale'
import pfFieldApiMethodParameters from '@/components/pfFieldApiMethodParameters'
import pfFieldPrefixTypeValue from '@/components/pfFieldPrefixTypeValue'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormBooleanBuilder from '@/components/pfFormBooleanBuilder'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
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
    label: 'Status', // i18n defer
    visible: true
  },
  {
    key: 'id',
    label: 'Name', // i18n defer
    required: true,
    visible: true
  },
  {
    key: 'description',
    label: 'Description', // i18n defer
    required: true,
    visible: true
  },
  {
    key: 'scopes',
    label: 'Scopes', // i18n defer
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

const answerFieldsFromMeta = (meta = {}) => {
  const { answers: { item: { properties: { type: { allowed = [], allowed_lookup: { search_path: searchPath, field_name: fieldName, value_name: valueName } = {} } = {} } = {} } = {} } = {} } = meta
  if (searchPath) {
    store.dispatch('lookup/postSearchPath', searchPath) // prime cache
    return store.getters['lookup/getFields'](searchPath, fieldName, valueName)
  }
  return allowed.map(allowed => {
    const { text, value } = allowed
    return { text, value, types: [fieldType.SUBSTRING] }
  })
}

const fieldOperatorsFromMeta = (meta = {}) => {
  const { condition: { properties: { field: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.map(allowed => {
    const { text, value, siblings: { value: { allowed_values } = {} } = {} } = allowed
    if (allowed_values) {
      return {
        text,
        value,
        options: allowed_values.concat().sort((a, b) => {
          return a.text.localeCompare(b.text)
        })
      }
    }
    return { text, value }
  }).sort((a, b) => {
    return a.text.localeCompare(b.text)
  })
}

const paramsFieldsFromMeta = (meta = {}) => {
  const { params: { item: { properties: { type:  { allowed = [] } = {} } = {} } = {} } = {} } = meta
  return allowed.map(allowed => {
    const { text, value } = allowed
    return { text, value, types: [fieldType.SUBSTRING] }
  })
}

const valueOperatorsFromMeta = (meta = {}) => {
  const { condition: { properties: { op: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.filter(allowed => {
    const { requires = [] } = allowed
    return !requires.includes('values')
  }).map(allowed => {
    const { requires = [], value } = allowed
    return { requires, value }
  })
}

const valuesOperatorsFromMeta = (meta = {}) => {
  const { condition: { properties: { op: { allowed = [] } = {} } = {} } = {} } = meta
  return allowed.filter(allowed => {
    const { requires = [] } = allowed
    return requires.includes('values') || requires.length === 0
  }).map(allowed => {
    const { value } = allowed
    return value
  })
}

export const viewFields = {
  id: (form, meta = {}) => {
    return {
      label: i18n.t('Name'),
      text: i18n.t('Specify a unique name for your filter.'),
      cols: [
        {
          namespace: 'id',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'id')
        }
      ]
    }
  },
  actions: (form, meta = {}) => {
    return {
      label: i18n.t('Actions'),
      text: i18n.t('Specify actions to perform when condition is met.'),
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
    }
  },
  answer: (form, meta = {}) => {
    return {
      label: i18n.t('Answer'),
      cols: [
        {
          namespace: 'answer',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'answer')
        }
      ]
    }
  },
  answers: (form, meta = {}) => {
    const { answers: { item: { properties: { prefix: { allowed: prefixes } = {} } = {} } = {} } = {} } = meta
    return {
      label: i18n.t('Answers'),
      cols: [
        {
          namespace: 'answers',
          component: pfFormFields,
          attrs: {
            buttonLabel: i18n.t('Add Answer'),
            sortable: true,
            field: {
              component: (prefixes)
                ? pfFieldPrefixTypeValue
                : pfFieldTypeValue,
              attrs: {
                prefixLabel: i18n.t('Select a prefix'),
                typeLabel: i18n.t('Select a type'),
                /*
                 * fallback to default behavior
                 * TODO - reimplement when allow_custom is removed, and allowed_lookup is updated.
                typeAttrs: attributesFromMeta(meta, 'answers.type'),
                */
                valueLabel: i18n.t('Select a value'),
                prefixes,
                fields: answerFieldsFromMeta(meta)
              }
            },
            invalidFeedback: i18n.t('Answers contain one or more errors.')
          }
        }
      ]
    }
  },
  condition: (form, meta = {}) => {
    return {
      label: i18n.t('Condition'),
      text: i18n.t('Specify a condition to match.'),
      cols: [
        {
          namespace: 'condition',
          component: pfFormBooleanBuilder,
          attrs: {
            fieldOperators: fieldOperatorsFromMeta(meta),
            valueOperators: valueOperatorsFromMeta(meta).map(({ requires, value }) => {
              const { [value]: text = value } = pfOperators
              return { text, value, requires }
            }),
            valuesOperators: valuesOperatorsFromMeta(meta).map(value => {
              const { [value]: text = value } = pfOperators
              return { text, value }
            }),
            invalidFeedback: i18n.t('Condition contains one or more errors.')
          }
        }
      ]
    }
  },
  description: (form, meta = {}) => {
    return {
      label: i18n.t('Description'),
      cols: [
        {
          namespace: 'description',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'description')
        }
      ]
    }
  },
  log: (form, meta = {}) => {
    return {
      label: i18n.t('Log Entry'),
      text: i18n.t('Specify the message to write to packetfence.log'),
      cols: [
        {
          namespace: 'log',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'log')
        }
      ]
    }
  },
  params: (form, meta = {}) => {
    return {
      label: i18n.t('Parameters'),
      text: i18n.t('Specify parameters to apply when condition is met.'),
      cols: [
        {
          namespace: 'params',
          component: pfFormFields,
          attrs: {
            buttonLabel: i18n.t('Add Parameter'),
            sortable: false,
            field: {
              component: pfFieldTypeValue,
              attrs: {
                typeLabel: i18n.t('Type'),
                valueLabel: i18n.t('Value'),
                fields: paramsFieldsFromMeta(meta)
              }
            },
            invalidFeedback: i18n.t('Parameters contain one or more errors.')
          }
        }
      ]
    }
  },
  merge_answer: () => {
    return {
      label: i18n.t('Merge Answer'),
      text: i18n.t('Enable to merge the following answers with the original RADIUS answers.'),
      cols: [
        {
          namespace: 'merge_answer',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'yes', unchecked: 'no' }
          }
        }
      ]
    }
  },
  radius_status: (form, meta = {}) => {
    return {
      label: i18n.t('RADIUS Status'),
      cols: [
        {
          namespace: 'radius_status',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'radius_status')
        }
      ]
    }
  },
  rcode: (form, meta = {}) => {
    return {
      label: i18n.t('Response Code'),
      cols: [
        {
          namespace: 'rcode',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'rcode')
        }
      ]
    }
  },
  run_actions: () => {
    return {
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
    }
  },
  role: (form, meta = {}) => {
    return {
      label: i18n.t('Role'),
      cols: [
        {
          namespace: 'role',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'role')
        }
      ]
    }
  },
  scopes: (form, meta = {}) => {
    return {
      label: i18n.t('Scopes'),
      cols: [
        {
          namespace: 'scopes',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'scopes')
        }
      ]
    }
  },
  status: () => {
    return {
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
    }
  },
  switch: (form, meta = {}) => {
    return {
      label: i18n.t('Switch'),
      text: i18n.t('Specify which switch module to use.'),
      cols: [
        {
          namespace: 'switch',
          component: pfFormChosen,
          attrs: {
            ...attributesFromMeta(meta, 'switch'),
            groupLabel: 'group',
            groupValues: 'options',
            optionsLimit: 1000,
            allowEmpty: true
          }
        }
      ]
    }
  }
}

const formKeyOrder = [
  'id',
  'description',
  'status',
  'log',
  'switch',
  'condition',
  'run_actions',
  'actions',
  'params',
  'merge_answer',
  'answers',
  'role',
  'scopes',
  'rcode',
  'radius_status',
]

export const view = (form = {}, meta = {}) => {
  const {
    run_actions
  } = form
  return [
    {
      tab: null,
      // meta indicates which fields are preset
      rows: Object.keys(meta).sort((a, b) => {
        if (formKeyOrder.includes(a) && formKeyOrder.includes(b)) {
          return formKeyOrder.indexOf(a) - formKeyOrder.indexOf(b)
        } else if (formKeyOrder.includes(a)) {
          return -1
        } else {
          return 1
        }
      }).filter(field => {
        switch (field) {
          case 'actions':
            return run_actions === 'enabled'
          default:
              return field in viewFields
        }
      }).map(field => {
        return viewFields[field](form, meta)
      })
    }
  ]
}

export const validatorFields = {
  id: (form, meta = {}) => {
    const { isNew, isClone, collection } = meta
    return {
      id: {
        ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
        ...{
          [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasFilterEngines(collection), filterEngineExists(collection)))
        }
      }
    }
  },
  actions: (form, meta = {}) => {
    const { actions = [] } = form
    return {
      actions: {
        ...validatorsFromMeta(meta, 'actions', i18n.t('Actions')),
        ...(actions || []).map(() => {
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
  },
  answers: (form, meta = {}) => {
    return {
      answers: {
        $each: {
          prefix: validatorsFromMeta(meta, 'answers.prefix', i18n.t('Prefix')),
          type: validatorsFromMeta(meta, 'answers.type', i18n.t('Type')),
          value: validatorsFromMeta(meta, 'answers.value', i18n.t('Value'))
        }
      }
    }
  },
  condition: (form, meta = {}) => {
    const requiresFieldsAssociated = valueOperatorsFromMeta(meta).reduce((associated, item) => {
        const { value, requires } = item
        associated[value] = requires
        return associated
      }, {})

    const validator = (meta = {}, condition = {}, level = 0) => {
      const { op, values } = condition
      if (values && values.constructor === Array) { // op
        return {
          op: {
            ...{
              [i18n.t('Operator required.')]: required
            },
            ...((level > 0) // require 2 values when not @ root condition
              ? {
                [i18n.t('Minimum 2 values required.')]: conditional(values.length >= 2)
              }
              : {}
            )
          },
          values: {
            ...(values || []).map(value => validator(meta, value, ++level))
          }
        }
      } else { // value
        const { [op]: requires = [] } = requiresFieldsAssociated
        const showField = (!op || requires.includes('field'))
        const showValue = (!op || requires.includes('value'))
        return {
          field: {
            ...((showField)
              ? { [i18n.t('Field required.')]: required }
              : {}
            )
          },
          op: {
            [i18n.t('Operator required.')]: required
          },
          value: {
            ...((showValue)
              ? { [i18n.t('Value required.')]: required }
              : {}
            )
          }
        }
      }
    }
    const { condition } = form
    return {
      condition: validator(meta, condition)
    }
  },
  description: () => {
    return {
      description: {
        [i18n.t('Description required.')]: required
      }
    }
  },
  params: (form, meta = {}) => {
    return {
      params: {
        $each: {
          type: validatorsFromMeta(meta, 'params.type', i18n.t('Type')),
          value: validatorsFromMeta(meta, 'params.value', i18n.t('Value'))
        }
      }
    }
  },
  role: (form, meta = {}) => {
    const { role, run_actions } = form
    return {
      role: {
        ...validatorsFromMeta(meta, 'role', i18n.t('Role')),
        ...((run_actions === 'disabled' && !role)
          ? {
            [i18n.t('Role required.')]: required
          }
          : {}
        )
      }
    }
  },
  scopes: (form, meta = {}) => {
    return {
      scopes: {
        ...validatorsFromMeta(meta, 'scopes', i18n.t('Scopes')),
        [i18n.t('Scopes required.')]: required
      }
    }
  }
}

export const validators = (form = {}, meta = {}) => {
  const {
    run_actions
  } = form
  // meta indicates which fields are preset
  return [ 'id', ...Object.keys(meta) ].filter(field => {
    switch (field) {
      case 'actions':
        return run_actions === 'enabled'
      default:
          return field in validatorFields
    }
  }).reduce((validators, field) => {
    return { ...validators, ...validatorFields[field](form, meta) }
  }, {})
}
