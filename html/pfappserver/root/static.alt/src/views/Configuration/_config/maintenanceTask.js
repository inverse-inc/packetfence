import { pfSchedulesList as schedulesList } from '@/globals/pfSchedules'
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasMaintenanceTasks,
  maintenanceTaskExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'status',
    label: 'Status', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'id',
    label: 'Task Name', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: 'Description', // i18n defer
    sortable: true,
    visible: true,
    formatter: value => i18n.t(value) // i18n defer
  },
  {
    key: 'schedule',
    label: 'Schedule', // i18n defer
    sortable: true,
    visible: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('Task Name'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
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

export const viewFields = {
  id: (_, meta = {}) => {
    return {
      label: i18n.t('Maintenance Task Name'),
      cols: [
        {
          namespace: 'id',
          component: pfFormInput,
          attrs: {
            ...attributesFromMeta(meta, 'id'),
            ...{
              disabled: true
            }
          }
        }
      ]
    }
  },
  batch: (_, meta = {}) => {
    return {
      label: i18n.t('Batch'),
      text: i18n.t('Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached.'),
      cols: [
        {
          namespace: 'batch',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'batch')
        }
      ]
    }
  },
  certificates: (_, meta = {}) => {
    return {
      label: i18n.t('Certificates'),
      text: i18n.t('SSL certificate(s) to monitor. Comma-separated list.'),
      cols: [
        {
          namespace: 'certificates',
          component: pfFormTextarea,
          attrs: {
            ...attributesFromMeta(meta, 'certificates'),
            ...{
              rows: 5
            }
          }
        }
      ]
    }
  },
  delay: (_, meta = {}) => {
    return {
      label: i18n.t('Delay'),
      text: i18n.t('Minimum gap before certificate expiration date (will the certificate expires in ...).'),
      cols: [
        {
          namespace: 'delay.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'delay.interval')
        },
        {
          namespace: 'delay.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'delay.unit')
        }
      ]
    }
  },
  delete_window: (_, meta = {}) => {
    return {
      label: i18n.t('Delete window'),
      text: i18n.t(`How long can an unregistered node be inactive before being deleted.\nThis shouldn't be used if you are using port-security.`),
      cols: [
        {
          namespace: 'delete_window.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'delete_window.interval')
        },
        {
          namespace: 'delete_window.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'delete_window.unit')
        }
      ]
    }
  },
  description: () => {
    return {
      label: i18n.t('Description'),
      cols: [
        {
          namespace: 'description',
          component: pfFormInput,
          attrs: {
            disabled: true
          }
        }
      ]
    }
  },
  schedule: () => {
    return {
      label: i18n.t('Schedule'),
      cols: [
        {
          namespace: 'schedule',
          component: pfFormChosen,
          attrs: {
            taggable: true,
            options: schedulesList
          }
        }
      ]
    }
  },
  process_switchranges: () => {
    return {
      label: i18n.t('Process switchranges'),
      text: i18n.t('Whether or not a switch range should be expanded to process each of its IPs.'),
      cols: [
        {
          namespace: 'rotate',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'Y', unchecked: 'N' }
          }
        }
      ]
    }
  },
  rotate: (_, __, logName = 'ip4log') => {
    return {
      label: i18n.t('Rotate'),
      text: i18n.t(`Enable or disable ${logName} rotation (moving ${logName}_history records to ${logName}_archive)\nIf disabled, this task will delete from the ${logName}_history table rather than the ${logName}_archive.`),
      cols: [
        {
          namespace: 'rotate',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'Y', unchecked: 'N' }
          }
        }
      ]
    }
  },
  rotate_batch: (_, meta = {}) => {
    return {
      label: i18n.t('Rotate batch'),
      text: i18n.t('Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached.'),
      cols: [
        {
          namespace: 'rotate_batch',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'rotate_batch')
        }
      ]
    }
  },
  rotate_timeout: (_, meta = {}) => {
    return {
      label: i18n.t('Rotate timeout'),
      text: i18n.t('Maximum amount of time this task can run.'),
      cols: [
        {
          namespace: 'rotate_timeout.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'rotate_timeout.interval')
        },
        {
          namespace: 'rotate_timeout.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'rotate_timeout.unit')
        }
      ]
    }
  },
  rotate_window: (_, meta = {}, logName = 'ip4log') => {
    return {
      label: i18n.t('Rotate window'),
      text: i18n.t(`How long to keep ${logName} history entry before rotating it to ${logName} archive.`),
      cols: [
        {
          namespace: 'rotate_window.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'rotate_window.interval')
        },
        {
          namespace: 'rotate_window.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'rotate_window.unit')
        }
      ]
    }
  },
  status: () => {
    return {
      label: i18n.t('Enabled'),
      text: i18n.t('Whether or not this task is enabled.\nRequires a restart of pfcron to be effective.'),
      cols: [
        {
          namespace: 'status',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  timeout: (_, meta = {}) => {
    return {
      label: i18n.t('Timeout'),
      text: i18n.t('Maximum amount of time this task can run.'),
      cols: [
        {
          namespace: 'timeout.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'timeout.interval')
        },
        {
          namespace: 'timeout.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'timeout.unit')
        }
      ]
    }
  },
  unreg_window: (_, meta = {}) => {
    return {
      label: i18n.t('Unreg window'),
      text: i18n.t('How long can a registered node be inactive before it becomes unregistered.'),
      cols: [
        {
          namespace: 'unreg_window.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'unreg_window.interval')
        },
        {
          namespace: 'unreg_window.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'unreg_window.unit')
        }
      ]
    }
  },
  voip: () => {
    return {
      label: i18n.t('VoIP'),
      text: i18n.t('Whether or not the VoIP devices should be handled by this maintenance task.'),
      cols: [
        {
          namespace: 'voip',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  window: (_, meta = {}) => {
    return {
      label: i18n.t('Window'),
      text: i18n.t('Window to apply the job to. In the case of a deletion, setting this to 7 days would delete affected data older than 7 days.'),
      cols: [
        {
          namespace: 'window.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'window.interval')
        },
        {
          namespace: 'window.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'window.unit')
        }
      ]
    }
  },
  history_batch: (_, meta = {}) => {
    return {
      label: i18n.t('History Batch'),
      text: i18n.t('Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached.'),
      cols: [
        {
          namespace: 'history_batch',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'history_batch')
        }
      ]
    }
  },
  history_timeout: (_, meta = {}) => {
    return {
      label: i18n.t('History Timeout'),
      text: i18n.t('Maximum amount of time this task can run.'),
      cols: [
        {
          namespace: 'history_timeout.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'history_timeout.interval')
        },
        {
          namespace: 'history_timeout.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'history_timeout.unit')
        }
      ]
    }
  },
  history_window: (_, meta = {}) => {
    return {
      label: i18n.t('History Window'),
      text: i18n.t('Window to apply the job to. In the case of a deletion, setting this to 7 days would delete affected data older than 7 days.'),
      cols: [
        {
          namespace: 'history_window.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'history_window.interval')
        },
        {
          namespace: 'history_window.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'history_window.unit')
        }
      ]
    }
  },
  session_batch: (_, meta = {}) => {
    return {
      label: i18n.t('Session Batch'),
      text: i18n.t('Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached.'),
      cols: [
        {
          namespace: 'session_batch',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'session_batch')
        }
      ]
    }
  },
  session_timeout: (_, meta = {}) => {
    return {
      label: i18n.t('Session Timeout'),
      text: i18n.t('Maximum amount of time this task can run.'),
      cols: [
        {
          namespace: 'session_timeout.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'session_timeout.interval')
        },
        {
          namespace: 'session_timeout.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'session_timeout.unit')
        }
      ]
    }
  },
  session_window: (_, meta = {}) => {
    return {
      label: i18n.t('Session Window'),
      text: i18n.t('Window to apply the job to. In the case of a deletion, setting this to 7 days would delete affected data older than 7 days.'),
      cols: [
        {
          namespace: 'session_window.interval',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'session_window.interval')
        },
        {
          namespace: 'session_window.unit',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'session_window.unit')
        }
      ]
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    id
  } = form
  switch (id) {
    case 'acct_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta),
            viewFields.window(form, meta)
          ]
        }
      ]
    case 'acct_maintenance':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'admin_api_audit_log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta),
            viewFields.window(form, meta)
          ]
        }
      ]
    case 'auth_log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta),
            viewFields.window(form, meta)
          ]
        }
      ]
    case 'bandwidth_maintenance':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.window(form, meta),
            viewFields.timeout(form, meta),
            viewFields.history_batch(form, meta),
            viewFields.history_timeout(form, meta),
            viewFields.history_window(form, meta)
          ]
        }
      ]
    case 'bandwidth_maintenance_session':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta),
            viewFields.window(form, meta)
          ]
        }
      ]
    case 'certificates_check':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.delay(form, meta),
            viewFields.certificates(form, meta)
          ]
        }
      ]
    case 'cleanup_chi_database_cache':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta)
          ]
        }
      ]
    case 'cluster_check':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'dns_audit_log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta),
            viewFields.window(form, meta)
          ]
        }
      ]
    case 'fingerbank_data_update':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'inline_accounting_maintenance':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'ip4log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta),
            viewFields.window(form, meta),
            viewFields.rotate(form, meta, 'ip4log'),
            viewFields.rotate_batch(form, meta),
            viewFields.rotate_timeout(form, meta),
            viewFields.rotate_window(form, meta, 'ip4log')
          ]
        }
      ]
    case 'ip6log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta),
            viewFields.window(form, meta),
            viewFields.rotate(form, meta, 'ip6log'),
            viewFields.rotate_batch(form, meta),
            viewFields.rotate_timeout(form, meta),
            viewFields.rotate_window(form, meta, 'ip6log')
          ]
        }
      ]
    case 'locationlog_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta),
            viewFields.window(form, meta)
          ]
        }
      ]
    case 'node_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.unreg_window(form, meta),
            viewFields.delete_window(form, meta),
            viewFields.voip(form, meta)
          ]
        }
      ]
    case 'nodes_maintenance':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'option82_query':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'password_of_the_day':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'person_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'populate_ntlm_redis_cache':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'provisioning_compliance_poll':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta)
          ]
        }
      ]
    case 'radius_audit_log_cleanup':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta),
            viewFields.window(form, meta)
          ]
        }
      ]
    case 'security_event_maintenance':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.batch(form, meta),
            viewFields.timeout(form, meta)
          ]
        }
      ]
    case 'switch_cache_lldpLocalPort_description':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.status(form, meta),
            viewFields.schedule(form, meta),
            viewFields.process_switchranges(form, meta)
          ]
        }
      ]
      /* keys are alphabetical, please insert new tasks in order above */
    default:
      return [
        {
          tab: null, // ignore tabs
          rows: []
        }
      ]
  }
}

export const validatorFields = {
  id: (_, meta = {}) => {
    const {
      isNew = false
    } = meta
    return {
      id: {
        ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
        ...{
          [i18n.t('Maintenance Task exists.')]: not(and(required, conditional(isNew), hasMaintenanceTasks, maintenanceTaskExists))
        }
      }
    }
  },
  batch: (_, meta = {}) => {
    return { batch: validatorsFromMeta(meta, 'batch', i18n.t('Batch')) }
  },
  certificates: (_, meta = {}) => {
    return { certificates: validatorsFromMeta(meta, 'certificates', i18n.t('Certificates')) }
  },
  delay: (_, meta = {}) => {
    return {
      delay: {
        interval: validatorsFromMeta(meta, 'delay.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'delay.unit', i18n.t('Unit'))
      }
    }
  },
  delete_window: (_, meta = {}) => {
    return {
      delete_window: {
        interval: validatorsFromMeta(meta, 'delete_window.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'delete_window.unit', i18n.t('Unit'))
      }
    }
  },
  description: () => {},
  interval: (_, meta = {}) => {
    return {
      interval: {
        interval: validatorsFromMeta(meta, 'interval.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'interval.unit', i18n.t('Unit'))
      }
    }
  },
  process_switchranges: () => {},
  rotate: () => {},
  rotate_batch: (_, meta = {}) => {
    return { rotate_batch: validatorsFromMeta(meta, 'rotate_batch', i18n.t('Batch')) }
  },
  rotate_timeout: (_, meta = {}) => {
    return {
      rotate_timeout: {
        interval: validatorsFromMeta(meta, 'rotate_timeout.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'rotate_timeout.unit', i18n.t('Unit'))
      }
    }
  },
  rotate_window: (_, meta = {}) => {
    return {
      rotate_window: {
        interval: validatorsFromMeta(meta, 'rotate_window.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'rotate_window.unit', i18n.t('Unit'))
      }
    }
  },
  status: () => {},
  timeout: (_, meta = {}) => {
    return {
      timeout: {
        interval: validatorsFromMeta(meta, 'timeout.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'timeout.unit', i18n.t('Unit'))
      }
    }
  },
  unreg_window: (_, meta = {}) => {
    return {
      unreg_window: {
        interval: validatorsFromMeta(meta, 'unreg_window.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'unreg_window.unit', i18n.t('Unit'))
      }
    }
  },
  window: (_, meta = {}) => {
    return {
      window: {
        interval: validatorsFromMeta(meta, 'window.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'window.unit', i18n.t('Unit'))
      }
    }
  },
  history_batch: (_, meta = {}) => {
    return { history_batch: validatorsFromMeta(meta, 'history_batch', i18n.t('Batch')) }
  },
  history_timeout: (_, meta = {}) => {
    return {
      history_timeout: {
        interval: validatorsFromMeta(meta, 'history_timeout.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'history_timeout.unit', i18n.t('Unit'))
      }
    }
  },
  history_window: (_, meta = {}) => {
    return {
      history_window: {
        interval: validatorsFromMeta(meta, 'history_window.interval', i18n.t('Interval')),
        unit: validatorsFromMeta(meta, 'history_window.unit', i18n.t('Unit'))
      }
    }
  }
}

export const validators = (form = {}, meta = {}) => {
  const {
    id
  } = form
  switch (id) {
    case 'acct_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.window(form, meta)
      }
    case 'acct_maintenance':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'admin_api_audit_log_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.window(form, meta)
      }
    case 'auth_log_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.window(form, meta)
      }
    case 'bandwidth_maintenance':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.history_window(form, meta),
        ...validatorFields.history_batch(form, meta),
        ...validatorFields.history_timeout(form, meta)
      }
    case 'bandwidth_maintenance_session':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.window(form, meta)
      }
    case 'certificates_check':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.delay(form, meta),
        ...validatorFields.certificates(form, meta)
      }
    case 'cleanup_chi_database_cache':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta)
      }
    case 'cluster_check':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'dns_audit_log_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.window(form, meta)
      }
    case 'fingerbank_data_update':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'inline_accounting_maintenance':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'ip4log_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.window(form, meta),
        ...validatorFields.rotate(form, meta, 'ip4log'),
        ...validatorFields.rotate_batch(form, meta),
        ...validatorFields.rotate_timeout(form, meta),
        ...validatorFields.rotate_window(form, meta, 'ip4log')
      }
    case 'ip6log_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.window(form, meta),
        ...validatorFields.rotate(form, meta, 'ip6log'),
        ...validatorFields.rotate_batch(form, meta),
        ...validatorFields.rotate_timeout(form, meta),
        ...validatorFields.rotate_window(form, meta, 'ip6log')
      }
    case 'locationlog_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.window(form, meta)
      }
    case 'node_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.unreg_window(form, meta),
        ...validatorFields.delete_window(form, meta)
      }
    case 'nodes_maintenance':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'option82_query':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'password_of_the_day':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'person_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'populate_ntlm_redis_cache':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'provisioning_compliance_poll':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta)
      }
    case 'radius_audit_log_cleanup':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta),
        ...validatorFields.window(form, meta)
      }
    case 'security_event_maintenance':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.batch(form, meta),
        ...validatorFields.timeout(form, meta)
      }
    case 'switch_cache_lldpLocalPort_description':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.status(form, meta),
        ...validatorFields.interval(form, meta),
        ...validatorFields.process_switchranges(form, meta)
      }
      /* keys are alphabetical, please insert new tasks in order above */
    default:
      return {}
  }
}
