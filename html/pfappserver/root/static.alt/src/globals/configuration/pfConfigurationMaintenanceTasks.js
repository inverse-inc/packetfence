import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasMaintenanceTasks,
  maintenanceTaskExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationMaintenanceTasksListColumns = [
  {
    key: 'status',
    label: i18n.t('Status'),
    sortable: true,
    visible: true
  },
  {
    key: 'id',
    label: i18n.t('Task Name'),
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  {
    key: 'interval',
    label: i18n.t('Interval'),
    sortable: true,
    visible: true
  }
]

export const pfConfigurationMaintenanceTasksListFields = [
  {
    value: 'id',
    text: i18n.t('Task Name'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationMaintenanceTasksListConfig = (context = {}) => {
  return {
    columns: pfConfigurationMaintenanceTasksListColumns,
    fields: pfConfigurationMaintenanceTasksListFields,
    rowClickRoute (item, index) {
      return { name: 'maintenance_task', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/maintenance_tasks',
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
      defaultRoute: { name: 'maintenance_tasks' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'description', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationMaintenanceTaskFields = {
  id: ({ isNew = false, isClone = false, options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Maintenance Task Name'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'id'),
            ...{
              disabled: true
            }
          },
          validators: {
            ...pfConfigurationValidatorsFromMeta(meta, 'id', i18n.t('Name')),
            ...{
              [i18n.t('Maintenance Task exists.')]: not(and(required, conditional(isNew || isClone), hasMaintenanceTasks, maintenanceTaskExists))
            }
          }
        }
      ]
    }
  },
  batch: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Batch'),
      text: i18n.t('Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached.'),
      fields: [
        {
          key: 'batch',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'batch'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'batch', i18n.t('Batch'))
        }
      ]
    }
  },
  certificates: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Certificates'),
      text: i18n.t('SSL certificate(s) to monitor. Comma-separated list.'),
      fields: [
        {
          key: 'certificates',
          component: pfFormTextarea,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'certificates'),
            ...{
              rows: 5
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'certificates', i18n.t('Certificates'))
        }
      ]
    }
  },
  delay: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Delay'),
      text: i18n.t('Minimum gap before certificate expiration date (will the certificate expires in ...).'),
      fields: [
        {
          key: 'delay.interval',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'delay.interval'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'delay.interval', i18n.t('Interval'))
        },
        {
          key: 'delay.unit',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'delay.unit'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'delay.unit', i18n.t('Unit'))
        }
      ]
    }
  },
  delete_window: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Delete window'),
      text: i18n.t(`How long can an unregistered node be inactive on the network before being deleted.\nThis shouldn't be used if you are using port-security.`),
      fields: [
        {
          key: 'delete_window.interval',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'delete_window.interval'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'delete_window.interval', i18n.t('Interval'))
        },
        {
          key: 'delete_window.unit',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'delete_window.unit'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'delete_window.unit', i18n.t('Unit'))
        }
      ]
    }
  },
  description: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Description'),
      fields: [
        {
          key: 'description',
          component: pfFormInput,
          attrs: {
            disabled: true
          }
        }
      ]
    }
  },
  interval: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Interval'),
      text: i18n.t('Interval (frequency) at which the task is executed.\nRequires a restart of pfmon to be fully effective. Otherwise, it will be taken in consideration next time the tasks runs.'),
      fields: [
        {
          key: 'interval.interval',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'interval.interval'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'interval.interval', i18n.t('Interval'))
        },
        {
          key: 'interval.unit',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'interval.unit'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'interval.unit', i18n.t('Unit'))
        }
      ]
    }
  },
  process_switchranges: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Process switchranges'),
      text: i18n.t('Whether or not a switch range should be expanded to process each of its IPs.'),
      fields: [
        {
          key: 'rotate',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'Y', unchecked: 'N' }
          }
        }
      ]
    }
  },
  rotate: ({ options: { meta = {} } } = {}, logName = 'ip4log') => {
    return {
      label: i18n.t('Rotate'),
      text: i18n.t(`Enable or disable ${logName} rotation (moving ${logName}_history records to ${logName}_archive)\nIf disabled, this task will delete from the ${logName}_history table rather than the ${logName}_archive.`),
      fields: [
        {
          key: 'rotate',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'Y', unchecked: 'N' }
          }
        }
      ]
    }
  },
  rotate_batch: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Rotate batch'),
      text: i18n.t('Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached.'),
      fields: [
        {
          key: 'rotate_batch',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'rotate_batch'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'rotate_batch', i18n.t('Batch'))
        }
      ]
    }
  },
  rotate_timeout: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Rotate timeout'),
      text: i18n.t('Maximum amount of time this task can run.'),
      fields: [
        {
          key: 'rotate_timeout.interval',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'rotate_timeout.interval'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'rotate_timeout.interval', i18n.t('Interval'))
        },
        {
          key: 'rotate_timeout.unit',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'rotate_timeout.unit'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'rotate_timeout.unit', i18n.t('Unit'))
        }
      ]
    }
  },
  rotate_window: ({ options: { meta = {} } } = {}, logName = 'ip4log') => {
    return {
      label: i18n.t('Rotate window'),
      text: i18n.t(`How long to keep ${logName} history entry before rotating it to ${logName} archive.`),
      fields: [
        {
          key: 'rotate_window.interval',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'rotate_window.interval'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'rotate_window.interval', i18n.t('Interval'))
        },
        {
          key: 'rotate_window.unit',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'rotate_window.unit'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'rotate_window.unit', i18n.t('Unit'))
        }
      ]
    }
  },
  status: () => {
    return {
      label: i18n.t('Enabled'),
      text: i18n.t('Whether or not this task is enabled.\nRequires a restart of pfmon to be effective.'),
      fields: [
        {
          key: 'status',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  timeout: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Timeout'),
      text: i18n.t('Maximum amount of time this task can run.'),
      fields: [
        {
          key: 'timeout.interval',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'timeout.interval'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'timeout.interval', i18n.t('Interval'))
        },
        {
          key: 'timeout.unit',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'timeout.unit'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'timeout.unit', i18n.t('Unit'))
        }
      ]
    }
  },
  unreg_window: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Unreg window'),
      text: i18n.t('How long can a registered node be inactive on the network before it becomes unregistered.'),
      fields: [
        {
          key: 'unreg_window.interval',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'unreg_window.interval'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'unreg_window.interval', i18n.t('Interval'))
        },
        {
          key: 'unreg_window.unit',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'unreg_window.unit'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'unreg_window.unit', i18n.t('Unit'))
        }
      ]
    }
  },
  window: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Window'),
      text: i18n.t('Window to apply the job to. In the case of a deletion, setting this to 7 days would delete affected data older than 7 days.'),
      fields: [
        {
          key: 'window.interval',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'window.interval'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'window.interval', i18n.t('Interval'))
        },
        {
          key: 'window.unit',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'window.unit'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'window.unit', i18n.t('Unit'))
        }
      ]
    }
  }
}

export const pfConfigurationMaintenanceTaskViewFields = (context) => {
  const {
    form: { id }
  } = context
  switch (id) {
    case 'acct_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context),
            pfConfigurationMaintenanceTaskFields.window(context)
          ]
        }
      ]
    case 'acct_maintenance':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    case 'auth_log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context),
            pfConfigurationMaintenanceTaskFields.window(context)
          ]
        }
      ]
    case 'cleanup_chi_database_cache':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context)
          ]
        }
      ]
    case 'cluster_check':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    case 'fingerbank_data_update':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    case 'inline_accounting_maintenance':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    case 'ip4log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context),
            pfConfigurationMaintenanceTaskFields.window(context),
            pfConfigurationMaintenanceTaskFields.rotate(context, 'ip4log'),
            pfConfigurationMaintenanceTaskFields.rotate_batch(context),
            pfConfigurationMaintenanceTaskFields.rotate_timeout(context),
            pfConfigurationMaintenanceTaskFields.rotate_window(context, 'ip4log')
          ]
        }
      ]
    case 'ip6log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context),
            pfConfigurationMaintenanceTaskFields.window(context),
            pfConfigurationMaintenanceTaskFields.rotate(context, 'ip6log'),
            pfConfigurationMaintenanceTaskFields.rotate_batch(context),
            pfConfigurationMaintenanceTaskFields.rotate_timeout(context),
            pfConfigurationMaintenanceTaskFields.rotate_window(context, 'ip6log')
          ]
        }
      ]
    case 'locationlog_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context),
            pfConfigurationMaintenanceTaskFields.window(context)
          ]
        }
      ]
    case 'node_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.unreg_window(context),
            pfConfigurationMaintenanceTaskFields.delete_window(context)
          ]
        }
      ]
    case 'nodes_maintenance':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    case 'option82_query':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    case 'person_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    case 'populate_ntlm_redis_cache':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    case 'provisioning_compliance_poll':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    case 'radius_audit_log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context),
            pfConfigurationMaintenanceTaskFields.window(context)
          ]
        }
      ]
    case 'dns_audit_log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context),
            pfConfigurationMaintenanceTaskFields.window(context)
          ]
        }
      ]
    case 'admin_api_audit_log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context),
            pfConfigurationMaintenanceTaskFields.window(context)
          ]
        }
      ]
    case 'security_event_maintenance':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.batch(context),
            pfConfigurationMaintenanceTaskFields.timeout(context)
          ]
        }
      ]
    case 'switch_cache_lldpLocalPort_description':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.process_switchranges(context)
          ]
        }
      ]
    case 'certificates_check':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context),
            pfConfigurationMaintenanceTaskFields.delay(context),
            pfConfigurationMaintenanceTaskFields.certificates(context)
          ]
        }
      ]
    case 'password_of_the_day':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationMaintenanceTaskFields.id(context),
            pfConfigurationMaintenanceTaskFields.description(context),
            pfConfigurationMaintenanceTaskFields.status(context),
            pfConfigurationMaintenanceTaskFields.interval(context)
          ]
        }
      ]
    default:
      return [
        {
          tab: null, // ignore tabs
          fields: []
        }
      ]
  }
}
