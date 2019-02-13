import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  or,
  not,
  conditional,
  isFQDN,
  isPort,
  hasSyslogForwarders,
  syslogForwarderExists
} from '@/globals/pfValidators'

const {
  ipAddress,
  maxLength,
  number,
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationSyslogForwardersLogs = [
  'fingerbank.log',
  'httpd.aaa.error',
  'httpd.aaa.access',
  'httpd.admin.access',
  'httpd.admin.catalyst',
  'httpd.admin.error',
  'httpd.admin.log',
  'httpd.collector.error',
  'httpd.collector.log',
  'httpd.parking.error',
  'httpd.parking.access',
  'httpd.portal.error',
  'httpd.portal.access',
  'httpd.portal.catalyst',
  'httpd.proxy.error',
  'httpd.proxy.access',
  'httpd.webservices.error',
  'httpd.webservices.access',
  'httpd.api-frontend.access',
  'api-frontend.log',
  'pfstats.log',
  'packetfence.log',
  'pfbandwidthd.log',
  'pfconfig.log',
  'pfdetect.log',
  'pfdhcplistener.log',
  'pfdns.log',
  'pffilter.log',
  'pfmon.log',
  'pfsso.log',
  'radius-acct.log',
  'radius-cli.log',
  'radius-eduroam.log',
  'radius-load_balancer.log',
  'radius.log',
  'redis_cache.log',
  'redis_ntlm_cache.log',
  'redis_queue.log',
  'redis_server.log',
  'mariadb_error.log',
  'haproxy_portal.log',
  'haproxy_db.log',
  'etcd.log'
]

export const pfConfigurationSyslogForwardersListColumns = [
  { ...pfConfigurationListColumns.id, ...{ label: i18n.t('Syslog Name') } }, // re-label
  { ...pfConfigurationListColumns.type, ...{ label: i18n.t('Type') } }, // re-label
  pfConfigurationListColumns.buttons
]

export const pfConfigurationSyslogForwardersListFields = [
  { ...pfConfigurationListFields.id, ...{ text: i18n.t('Syslog Name') } }, // re-text
  pfConfigurationListFields.type
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
    syslogForwarder: form = {}
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
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Value required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Syslog Forwarder exists.')]: not(and(required, conditional(isNew || isClone), hasSyslogForwarders, syslogForwarderExists))
              }
            }
          ]
        },
        {
          label: i18n.t('Protocol'),
          fields: [
            {
              key: 'proto',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a protocol'),
                trackBy: 'value',
                label: 'text',
                options: ['udp', 'tcp'].map(proto => { return { value: proto, text: proto } })
              },
              validators: {
                [i18n.t('Value required.')]: required
              }
            }
          ]
        },
        {
          label: i18n.t('Host'),
          fields: [
            {
              key: 'host',
              component: pfFormInput,
              validators: {
                [i18n.t('Value required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Invalid Hostname or IP Address.')]: or(isFQDN, ipAddress)
              }
            }
          ]
        },
        {
          label: i18n.t('Port'),
          fields: [
            {
              key: 'port',
              component: pfFormInput,
              attrs: {
                type: number,
                step: 1
              },
              validators: {
                [i18n.t('Value required.')]: required,
                [i18n.t('Invalid Port Number.')]: isPort
              }
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
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a log'),
                trackBy: 'value',
                label: 'text',
                multiple: true,
                clearOnSelect: false,
                closeOnSelect: false,
                options: pfConfigurationSyslogForwardersLogs.map(log => { return { value: log, text: log } })
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationSyslogForwarderViewDefaults = (context = {}) => {
  return {
    all_logs: 'enabled',
    logs: pfConfigurationSyslogForwardersLogs
  }
}
