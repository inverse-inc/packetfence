/* eslint-disable camelcase */
import Vue from 'vue'
import store from '@/store'
import i18n from '@/utils/locale'
import pfFieldApiMethodParameters from '@/components/pfFieldApiMethodParameters'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
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

const answerFieldsFromMeta = (meta = {}) => {
  const { answers: { item: { properties: { type: { allowed = [] } = {} } = {} } = {} } = {} } = meta
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

export const viewFields = {
  id: (form, meta = {}) => {
    const { isNew = false, isClone = false } = meta
    return {
      label: i18n.t('Name'),
      text: i18n.t('Specify a unique name for your filter.'),
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
    }
  },
  actions: (form, meta = {}) => {
    return {
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
              component: pfFieldTypeValue,
              attrs: {
                typeLabel: i18n.t('Select answer type'),
                valueLabel: i18n.t('Select answer value'),
                fields: answerFieldsFromMeta(meta)
              }
            },
            invalidFeedback: i18n.t('Answers contain one or more errors.')
          }
        }
      ]
    }
  },
  answersRadiusAttributes:(form, meta = {}) => {
    let fields = Vue.observable([])
    store.dispatch('radius/getAttributes').then(radiusAttributes => {
      Object.values(radiusAttributes)
        .sort((a, b) => a.name.localeCompare(b.name))
        .map((radiusAttribute, index) => {
          const { name, name: value, vendor, allowed_values } = radiusAttribute
          if (allowed_values) { // has allowed values
            Vue.set(fields, index, {
              text: ((vendor)
                ? `${name} (${vendor})`
                : name
              ),
              value,
              types: [fieldType.OPTIONS],
              attrs: {
                options: allowed_values.map(allowed => {
                  const { name, value } = allowed
                  return { name, value: `${value}` } // cast string to support 0
                })
              }
            })
          } else { // user input
            Vue.set(fields, index, {
              text: ((vendor)
                ? `${name} (${vendor})`
                : name
              ),
              value,
              types: [fieldType.SUBSTRING]
            })
          }
        })
    })
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
              component: pfFieldTypeValue,
              attrs: {
                typeLabel: i18n.t('Type to filter RADIUS attributes'),
                valueLabel: i18n.t('Select value'),
                fields
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
  merge_answer: (form, meta = {}) => {
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
  run_actions: (form, meta = {}) => {
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
  status: (form, meta = {}) => {
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
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false,
    collection = null
  } = meta
  switch (collection) {
    case 'dhcp_filters':
      return [
        {
          tab: null,
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.condition(form, meta),
            viewFields.run_actions(form, meta),
            viewFields.actions(form, meta),
            viewFields.answers(form, meta),
            viewFields.scopes(form, meta)
          ]
        }
      ]
    case 'dns_filters':
      return [
        {
          tab: null,
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.condition(form, meta),
            viewFields.scopes(form, meta),
            viewFields.answer(form, meta),
            viewFields.rcode(form, meta)
          ]
        }
      ]
    case 'radius_filters':
      return [
        {
          tab: null,
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.condition(form, meta),
            viewFields.merge_answer(form, meta),
            viewFields.answersRadiusAttributes(form, meta),
            viewFields.scopes(form, meta),
            viewFields.radius_status(form, meta)
          ]
        }
      ]
    case 'vlan_filters':
      return [
        {
          tab: null,
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.condition(form, meta),
            viewFields.role(form, meta),
            viewFields.scopes(form, meta)
          ]
        }
      ]
    default:
      return [
        {
          tab: null,
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta)
          ]
        }
      ]
  }
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
    const { actions = [], run_actions } = form
    return {
      actions: {
        ...((run_actions === 'enabled' && (!actions || actions.length === 0))
          ? {
            [i18n.t('Actions required.')]: required
          }
          : {}
        ),
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
  },
  condition: (form, meta = {}) => {
    const validator = (meta = {}, condition = {}, level = 0) => {
      const { field, op, value, values } = condition
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
    const { condition } = form
    return {
      condition: validator(meta, condition)
    }
  },
  description: (form, meta = {}) => {
    return {
      description: {
        [i18n.t('Description required.')]: required
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
  const { collection = null } = meta
  switch (collection) {
    case 'dhcp_filters':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.condition(form, meta),
        ...validatorFields.actions(form, meta),
        ...validatorFields.scopes(form, meta)
      }
    case 'dns_filters':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.condition(form, meta),
        ...validatorFields.scopes(form, meta)
      }
    case 'radius_filters':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.condition(form, meta),
        ...validatorFields.scopes(form, meta)
      }
    case 'vlan_filters':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.condition(form, meta),
        ...validatorFields.role(form, meta),
        ...validatorFields.scopes(form, meta)
      }
    default:
      return {}
  }
}
