import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasSyslogForwarders,
  syslogForwarderExists
} from '@/globals/pfValidators'

const { required } = require('vuelidate/lib/validators')

export const pfConfigurationSyslogForwardersListColumns = [
  {
    key: 'id',
    label: i18n.t('Syslog Name'),
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: i18n.t('Type'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    sortable: false,
    visible: true,
    locked: true
  }
]

export const pfConfigurationSyslogForwardersListFields = [
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

export const pfConfigurationSyslogForwardersListConfig = (context = {}) => {
  return {
    columns: pfConfigurationSyslogForwardersListColumns,
    fields: pfConfigurationSyslogForwardersListFields,
    rowClickRoute (item, index) {
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

export const pfConfigurationSyslogForwarderViewFields = (context) => {
  const {
    isNew = false,
    isClone = false,
    form = {},
    options: {
      meta = {}
    }
  } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('Syslog Name'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'id', 'ID'),
                ...{
                  [i18n.t('Syslog Forwarder exists.')]: not(and(required, conditional(isNew || isClone), hasSyslogForwarders, syslogForwarderExists))
                }
              }
            }
          ]
        },
        {
          if: ['server'].includes(form.type),
          label: i18n.t('Protocol'),
          fields: [
            {
              key: 'proto',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'proto'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'proto', i18n.t('Protocol'))
            }
          ]
        },
        {
          if: ['server'].includes(form.type),
          label: i18n.t('Host'),
          fields: [
            {
              key: 'host',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'host'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'host', i18n.t('Host'))
            }
          ]
        },
        {
          if: ['server'].includes(form.type),
          label: i18n.t('Port'),
          fields: [
            {
              key: 'port',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'port'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'port', i18n.t('Port'))
            }
          ]
        },
        {
          label: i18n.t('All logs'),
          fields: [
            {
              key: 'all_logs',
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
          fields: [
            {
              key: 'logs',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'logs'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'logs', i18n.t('Logs'))
            }
          ]
        }
      ]
    }
  ]
}
