import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasSyslogForwarders,
  syslogForwarderExists
} from '@/globals/pfValidators'
import { required } from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: 'Syslog Name', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: 'Type', // i18n defer
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
    text: i18n.t('Syslog Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'syslogForwarder', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by Syslog name or type'),
    searchableOptions: {
      searchApiEndpoint: 'config/syslog_forwarders',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'type', op: 'contains', value: null },
            { field: 'proto', op: 'contains', value: null },
            { field: 'host', op: 'contains', value: null },
            { field: 'port', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'syslogForwarders' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: quickCondition },
            { field: 'type', op: 'contains', value: quickCondition },
            { field: 'proto', op: 'contains', value: quickCondition },
            { field: 'host', op: 'contains', value: quickCondition },
            { field: 'port', op: 'contains', value: quickCondition }
          ]
        }]
      }
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('Syslog Name'),
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
          if: ['server'].includes(form.type),
          label: i18n.t('Protocol'),
          cols: [
            {
              namespace: 'proto',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'proto')
            }
          ]
        },
        {
          if: ['server'].includes(form.type),
          label: i18n.t('Host'),
          cols: [
            {
              namespace: 'host',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'host')
            }
          ]
        },
        {
          if: ['server'].includes(form.type),
          label: i18n.t('Port'),
          cols: [
            {
              namespace: 'port',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'port')
            }
          ]
        },
        {
          label: i18n.t('All logs'),
          cols: [
            {
              namespace: 'all_logs',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: form.all_logs === 'disabled',
          label: i18n.t('Logs'),
          cols: [
            {
              namespace: 'logs',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'logs')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'ID'),
      ...{
        [i18n.t('Syslog Forwarder exists.')]: not(and(required, conditional(isNew || isClone), hasSyslogForwarders, syslogForwarderExists))
      }
    },
    proto: validatorsFromMeta(meta, 'proto', i18n.t('Protocol')),
    host: validatorsFromMeta(meta, 'host', i18n.t('Host')),
    port: validatorsFromMeta(meta, 'port', i18n.t('Port')),
    logs: validatorsFromMeta(meta, 'logs', i18n.t('Logs'))
  }
}
