import store from '@/store'
import i18n from '@/utils/locale'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasSwitchTemplates,
  switchTemplateExists
} from '@/globals/pfValidators'
import { required } from 'vuelidate/lib/validators'

export const columns = [
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
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'radiusDisconnect',
    label: i18n.t('RADIUS Disconnect'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  },
  {
    key: 'description',
    label: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'switchTemplate', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by Identifier or Description'),
    searchableOptions: {
      searchApiEndpoint: 'config/template_switches',
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
      defaultRoute: { name: 'switchTemplates' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: quickCondition },
            { field: 'description', op: 'contains', value: quickCondition }
          ]
        }]
      }
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false,
    radiusAttributes = {}
  } = meta

  const radiusFields = Object.keys(radiusAttributes).sort((a, b) => {
    return a.localeCompare(b)
  }).map(key => {
    const { [key]: radiusAttribute, [key]: { allowed_values } = {} } = radiusAttributes
    if (allowed_values) {
      return {
        value: key,
        text: key,
        types: [fieldType.OPTIONS],
        options: allowed_values.map(option => {
          return { text: option.name, value: option.value }
        })
      }
    } else {
      return {
        value: key,
        text: key,
        types: [fieldType.RADIUSATTRIBUTE]
      }
    }
  })

  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('Identifier'),
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
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'description')
            }
          ]
        },
        {
          label: i18n.t('RADIUS Disconnect'),
          cols: [
            {
              namespace: 'radiusDisconnect',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'radiusDisconnect')
            }
          ]
        },
        {
          label: i18n.t('SNMP Disconnect'),
          text: i18n.t(`Use SNMP instead of RADIUS to perform access reevaluation. This will perform an SNMP up/down on the port using the standard MIB.`),
          cols: [
            {
              namespace: 'snmpDisconnect',
              component: pfFormRangeToggle,
              attrs: attributesFromMeta(meta, 'snmpDisconnect')
            }
          ]
        },
        {
          label: i18n.t('Accept VLAN Scope'),
          cols: [
            {
              namespace: 'acceptVlan',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add RADIUS Attribute'),
                sortable: true,
                field: {
                  component: pfFieldTypeValue,
                  attrs: {
                    typeLabel: i18n.t('Type to filter RADIUS attributes'),
                    valueLabel: i18n.t('Select value'),
                    fields: radiusFields
                  }
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Accept Role Scope'),
          cols: [
            {
              namespace: 'acceptRole',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add RADIUS Attribute'),
                sortable: true,
                field: {
                  component: pfFieldTypeValue,
                  attrs: {
                    typeLabel: i18n.t('Type to filter RADIUS attributes'),
                    valueLabel: i18n.t('Select value'),
                    fields: radiusFields
                  }
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Disconnect Scope'),
          cols: [
            {
              namespace: 'disconnect',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add RADIUS Attribute'),
                sortable: true,
                field: {
                  component: pfFieldTypeValue,
                  attrs: {
                    typeLabel: i18n.t('Type to filter RADIUS attributes'),
                    valueLabel: i18n.t('Select value'),
                    fields: radiusFields
                  }
                }
              }
            }
          ]
        },
        {
          label: i18n.t('CoA Scope'),
          cols: [
            {
              namespace: 'coa',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add RADIUS Attribute'),
                sortable: true,
                field: {
                  component: pfFieldTypeValue,
                  attrs: {
                    typeLabel: i18n.t('Type to filter RADIUS attributes'),
                    valueLabel: i18n.t('Select value'),
                    fields: radiusFields
                  }
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Reject Scope'),
          cols: [
            {
              namespace: 'reject',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add RADIUS Attribute'),
                sortable: true,
                field: {
                  component: pfFieldTypeValue,
                  attrs: {
                    typeLabel: i18n.t('Type to filter RADIUS attributes'),
                    valueLabel: i18n.t('Select value'),
                    fields: radiusFields
                  }
                }
              }
            }
          ]
        },
        {
          label: i18n.t('VOIP Scope'),
          cols: [
            {
              namespace: 'voip',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add RADIUS Attribute'),
                sortable: true,
                field: {
                  component: pfFieldTypeValue,
                  attrs: {
                    typeLabel: i18n.t('Type to filter RADIUS attributes'),
                    valueLabel: i18n.t('Select value'),
                    fields: radiusFields
                  }
                }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form, meta = {}) => {
  const {
    acceptVlan = [],
    acceptRole = [],
    disconnect = [],
    coa = [],
    reject = [],
    voip = []
  } = form
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'ID'),
      ...{
        [i18n.t('Syslog Forwarder exists.')]: not(and(required, conditional(isNew || isClone), hasSwitchTemplates, switchTemplateExists))
      }
    },
    description: {
      [i18n.t('Description required.')]: required
    },
    acceptVlan: {
      ...(acceptVlan || []).map(_acceptVlan => { // index based validators
        if (_acceptVlan) {
          const { type } = _acceptVlan
          if (type) {
            return { value: { [i18n.t('Value required.')]: required } }
          }
        }
        return { type: { [i18n.t('Attribute required')]: required } }
      })
    },
    acceptRole: {
      ...(acceptRole || []).map(_acceptRole => { // index based validators
        if (_acceptRole) {
          const { type } = _acceptRole
          if (type) {
            return { value: { [i18n.t('Value required.')]: required } }
          }
        }
        return { type: { [i18n.t('Attribute required')]: required } }
      })
    },
    disconnect: {
      ...(disconnect || []).map(_disconnect => { // index based validators
        if (_disconnect) {
          const { type } = _disconnect
          if (type) {
            return { value: { [i18n.t('Value required.')]: required } }
          }
        }
        return { type: { [i18n.t('Attribute required')]: required } }
      })
    },
    coa: {
      ...(coa || []).map(_coa => { // index based validators
        if (_coa) {
          const { type } = _coa
          if (type) {
            return { value: { [i18n.t('Value required.')]: required } }
          }
        }
        return { type: { [i18n.t('Attribute required')]: required } }
      })
    },
    reject: {
      ...(reject || []).map(_reject => { // index based validators
        if (_reject) {
          const { type } = _reject
          if (type) {
            return { value: { [i18n.t('Value required.')]: required } }
          }
        }
        return { type: { [i18n.t('Attribute required')]: required } }
      })
    },
    voip: {
      ...(voip || []).map(_voip => { // index based validators
        if (_voip) {
          const { type } = _voip
          if (type) {
            return { value: { [i18n.t('Value required.')]: required } }
          }
        }
        return { type: { [i18n.t('Attribute required')]: required } }
      })
    }
  }
}
