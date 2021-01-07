import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '../'

export const view = (_, meta = {}) => {
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('API Key'),
          text: i18n.t('API key to interact with upstream Fingerbank project. Changing this value requires to restart the Fingerbank collector.'),
          cols: [
            {
              namespace: 'upstream.api_key',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'upstream.api_key')
            }
          ]
        },
        {
          label: i18n.t('Upstream API host'),
          text: i18n.t('The host on which the Fingerbank API should be reached.'),
          cols: [
            {
              namespace: 'upstream.host',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'upstream.host')
            }
          ]
        },
        {
          label: i18n.t('Upstream API port'),
          text: i18n.t('The port on which the Fingerbank API should be reached.'),
          cols: [
            {
              namespace: 'upstream.port',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'upstream.port')
            }
          ]
        },
        {
          label: i18n.t('Upstream API HTTPS'),
          text: i18n.t('Whether or not HTTPS should be used to communicate with the Fingerbank API.'),
          cols: [
            {
              namespace: 'upstream.use_https',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Database API path'),
          text: i18n.t('Path used to fetch the database on the Fingerbank API.'),
          cols: [
            {
              namespace: 'upstream.db_path',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'upstream.db_path')
            }
          ]
        },
        {
          label: i18n.t('Retention of the upstream sqlite DB'),
          text: i18n.t('Amount of upstream databases to retain on disk in db/. Should be at least one in case any running processes are still pointing on the old file descriptor of the database.'),
          cols: [
            {
              namespace: 'upstream.sqlite_db_retention',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'upstream.sqlite_db_retention')
            }
          ]
        },
        {
          label: i18n.t('Collector host'),
          text: i18n.t('The host on which the Fingerbank collector should be reached.'),
          cols: [
            {
              namespace: 'collector.host',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'collector.host')
            }
          ]
        },
        {
          label: i18n.t('Collector port'),
          text: i18n.t('The port on which the Fingerbank collector should be reached.'),
          cols: [
            {
              namespace: 'collector.port',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'collector.port')
            }
          ]
        },
        {
          label: i18n.t('Collector HTTPS'),
          text: i18n.t('Whether or not HTTPS should be used to communicate with the collector.'),
          cols: [
            {
              namespace: 'collector.use_https',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Inactive endpoints expiration'),
          text: i18n.t('Amount of hours after which the information inactive endpoints should be removed from the collector.'),
          cols: [
            {
              namespace: 'collector.inactive_endpoints_expiration',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'collector.inactive_endpoints_expiration')
            }
          ]
        },
        {
          label: i18n.t('ARP lookups by the collector'),
          text: i18n.t(`Whether or not the collector should perform ARP lookups for devices it doesn't have DHCP information.`),
          cols: [
            {
              namespace: 'collector.arp_lookup',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Network behavior analysis'),
          text: i18n.t(`Whether or not the collector should perform network behavior analysis of the endpoints it sees.`),
          cols: [
            {
              namespace: 'collector.network_behavior_analysis',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Query cache time in the collector'),
          text: i18n.t('Amount of minutes for which the collector API query results are cached.'),
          cols: [
            {
              namespace: 'collector.query_cache_time',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'collector.query_cache_time')
            }
          ]
        },
        {
          label: i18n.t('Database persistence interval'),
          text: i18n.t('Interval in seconds at which the collector will persist its databases.'),
          cols: [
            {
              namespace: 'collector.db_persistence_interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'collector.db_persistence_interval')
            }
          ]
        },
        {
          label: i18n.t('Cluster resync interval'),
          text: i18n.t('Interval in seconds at which the collector will fully resynchronize with its peers when in cluster mode. The collector synchronizes in real-time, so this only acts as a safety net when there is a communication error between the collectors.'),
          cols: [
            {
              namespace: 'collector.cluster_resync_interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'collector.cluster_resync_interval')
            }
          ]
        },
        {
          label: i18n.t('Record Unmatched Parameters'),
          text: i18n.t('Should the local instance of Fingerbank record unmatched parameters so that it will be possible to submit thoses unmatched parameters to the upstream Fingerbank project for contribution.'),
          cols: [
            {
              namespace: 'query.record_unmatched',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use proxy'),
          text: i18n.t('Should Fingerbank interact with WWW using a proxy?'),
          cols: [
            {
              namespace: 'proxy.use_proxy',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Proxy Host'),
          text: i18n.t('Host the proxy is listening on. Only the host must be specified here without any port or protocol.'),
          cols: [
            {
              namespace: 'proxy.host',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'proxy.host')
            }
          ]
        },
        {
          label: i18n.t('Proxy Port'),
          text: i18n.t('Port the proxy is listening on.'),
          cols: [
            {
              namespace: 'proxy.port',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'proxy.port')
            }
          ]
        },
        {
          label: i18n.t('Verify SSL'),
          text: i18n.t('Whether or not to verify SSL when using proxying.'),
          cols: [
            {
              namespace: 'proxy.verify_ssl',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (_, meta = {}) => {
  return {
    upstream: {
      api_key: validatorsFromMeta(meta, 'upstream.api_key', i18n.t('Key')),
      host: validatorsFromMeta(meta, 'upstream.host', i18n.t('Host')),
      port: validatorsFromMeta(meta, 'upstream.port', i18n.t('Port')),
      db_path: validatorsFromMeta(meta, 'upstream.db_path', i18n.t('Path')),
      sqlite_db_retention: validatorsFromMeta(meta, 'upstream.sqlite_db_retention', i18n.t('Amount'))
    },
    collector: {
      host: validatorsFromMeta(meta, 'collector.host', i18n.t('Host')),
      port: validatorsFromMeta(meta, 'collector.port', i18n.t('Port')),
      inactive_endpoints_expiration: validatorsFromMeta(meta, 'collector.inactive_endpoints_expiration', i18n.t('Hours')),
      query_cache_time: validatorsFromMeta(meta, 'collector.query_cache_time', i18n.t('Time')),
      db_persistence_interval: validatorsFromMeta(meta, 'collector.db_persistence_interval', i18n.t('Interval')),
      cluster_resync_interval: validatorsFromMeta(meta, 'collector.cluster_resync_interval', i18n.t('Interval'))
    },
    proxy: {
      host: validatorsFromMeta(meta, 'proxy.host', i18n.t('Host')),
      port: validatorsFromMeta(meta, 'proxy.port', i18n.t('Port'))
    }
  }
}
