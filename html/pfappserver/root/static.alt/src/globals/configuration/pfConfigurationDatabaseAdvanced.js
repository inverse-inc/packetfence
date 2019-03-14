import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationDatabaseAdvancedViewFields = (context = {}) => {
  const {
    options: {
      meta = {}
    }
  } = context
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Key buffer size'),
          text: i18n.t('The key_buffer_size MySQL configuration attribute (in MB). Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'key_buffer_size',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'key_buffer_size'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'key_buffer_size', 'Size')
            }
          ]
        },
        {
          label: i18n.t('InnoDB buffer pool size'),
          text: i18n.t('The innodb_buffer_pool_size MySQL configuration attribute (in MB). Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'innodb_buffer_pool_size',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'innodb_buffer_pool_size'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'innodb_buffer_pool_size', 'Size')
            }
          ]
        },
        {
          label: i18n.t('InnoDB additionnal mem pool size'),
          text: i18n.t('The innodb_additional_mem_pool_size MySQL configuration attribute (in MB). Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'innodb_additional_mem_pool_size',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'innodb_additional_mem_pool_size'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'innodb_additional_mem_pool_size', 'Size')
            }
          ]
        },
        {
          label: i18n.t('Query cache size'),
          text: i18n.t('The query_cache_size MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'query_cache_size',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'query_cache_size'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'query_cache_size', 'Size')
            }
          ]
        },
        {
          label: i18n.t('Thread concurrency'),
          text: i18n.t('The thread_concurrency MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'thread_concurrency',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'thread_concurrency'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'thread_concurrency', 'Concurrency')
            }
          ]
        },
        {
          label: i18n.t('Max connections'),
          text: i18n.t('The max_connections MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'max_connections',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'max_connections'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'max_connections', 'Connections')
            }
          ]
        },
        {
          label: i18n.t('Table cache'),
          text: i18n.t('The table_cache MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'table_cache',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'table_cache'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'table_cache', 'Cache')
            }
          ]
        },
        {
          label: i18n.t('Thread cache size'),
          text: i18n.t('The thread_cache_size MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'thread_cache_size',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'thread_cache_size'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'thread_cache_size', 'Size')
            }
          ]
        },
        {
          label: i18n.t('Max allowed packets'),
          text: i18n.t('The max_allowed_packet MySQL configuration attribute (in MB). Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'max_allowed_packet',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'max_allowed_packet'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'max_allowed_packet', 'Packets')
            }
          ]
        },
        {
          label: i18n.t('Performance schema'),
          text: i18n.t('The performance_schema MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'performance_schema',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'performance_schema'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'performance_schema', 'Schema')
            }
          ]
        },
        {
          label: i18n.t('Max connect errors'),
          text: i18n.t('The max_connect_errors MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.'),
          fields: [
            {
              key: 'max_connect_errors',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'max_connect_errors'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'max_connect_errors', 'Errors')
            }
          ]
        }
      ]
    }
  ]
}
