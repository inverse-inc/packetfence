<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-key-buffer-size namespace="key_buffer_size"
      :column-label="$i18n.t('Key buffer size')"
      :text="$i18n.t('The key_buffer_size MySQL configuration attribute (in MB). Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-innodb-buffer-pool-size namespace="innodb_buffer_pool_size"
      :column-label="$i18n.t('InnoDB buffer pool size')"
      :text="$i18n.t('The innodb_buffer_pool_size MySQL configuration attribute (in MB). Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-innodb-additional-mem-pool-size namespace="innodb_additional_mem_pool_size"
      :column-label="$i18n.t('InnoDB additionnal mem pool size')"
      :text="$i18n.t('The innodb_additional_mem_pool_size MySQL configuration attribute (in MB). Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-query-cache-size namespace="query_cache_size"
      :column-label="$i18n.t('Query cache size')"
      :text="$i18n.t('The query_cache_size MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-thread-concurrency namespace="thread_concurrency"
      :column-label="$i18n.t('Thread concurrency')"
      :text="$i18n.t('The thread_concurrency MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-max-connections namespace="max_connections"
      :column-label="$i18n.t('Max connections')"
      :text="$i18n.t('The max_connections MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-table-cache namespace="table_cache"
      :column-label="$i18n.t('Table cache')"
      :text="$i18n.t('The table_cache MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-thread-cache-size namespace="thread_cache_size"
      :column-label="$i18n.t('Thread cache size')"
      :text="$i18n.t('The thread_cache_size MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-max-allowed-packet namespace="max_allowed_packet"
      :column-label="$i18n.t('Max allowed packets')"
      :text="$i18n.t('The max_allowed_packet MySQL configuration attribute (in MB). Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-performance-schema namespace="performance_schema"
      :column-label="$i18n.t('Performance schema')"
      :text="$i18n.t('The performance_schema MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-max-connect-errors namespace="max_connect_errors"
      :column-label="$i18n.t('Max connect errors')"
      :text="$i18n.t('The max_connect_errors MySQL configuration attribute. Only change if you know what you are doing. Will only affect a locally running MySQL server.')"
    />

    <form-group-masterslave namespace="masterslave"
      :column-label="$i18n.t('Master/Slave mode')"
      :text="$i18n.t('Enable master/slave replication.')"
    />

    <form-group-other-members namespace="other_members"
      :column-label="$i18n.t('Other MySQL Servers')"
      :text="$i18n.t('Comma delimited IPv4 address of other member MySQL members - used to sync the database.')"
    />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupKeyBufferSize,
  FormGroupInnodbBufferPoolSize,
  FormGroupInnodbAdditionalMemPoolSize,
  FormGroupQueryCacheSize,
  FormGroupThreadConcurrency,
  FormGroupMaxConnections,
  FormGroupTableCache,
  FormGroupThreadCacheSize,
  FormGroupMaxAllowedPacket,
  FormGroupPerformanceSchema,
  FormGroupMaxConnectErrors,
  FormGroupMasterslave,
  FormGroupOtherMembers
} from './'

const components = {
  BaseForm,

  FormGroupKeyBufferSize,
  FormGroupInnodbBufferPoolSize,
  FormGroupInnodbAdditionalMemPoolSize,
  FormGroupQueryCacheSize,
  FormGroupThreadConcurrency,
  FormGroupMaxConnections,
  FormGroupTableCache,
  FormGroupThreadCacheSize,
  FormGroupMaxAllowedPacket,
  FormGroupPerformanceSchema,
  FormGroupMaxConnectErrors,
  FormGroupMasterslave,
  FormGroupOtherMembers
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {

  const schema = computed(() => schemaFn(props))

  return {
    schema
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

