<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Maintenance Task Name')"
      disabled
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
      disabled
    />

    <form-group-status namespace="status"
      :column-label="$i18n.t('Status')"
      :text="$i18n.t('Whether or not this task is enabled.\nRequires a restart of pfcron to be effective.')"
    />

    <form-group-schedule v-show="wants('schedule')"
      namespace="schedule"
      :column-label="$i18n.t('Schedule')"
      :options="schedulesOptions"
      taggable
    />

    <form-group-batch v-show="wants('batch')"
      namespace="batch"
      :column-label="$i18n.t('Batch')"
      :text="$i18n.t('Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached.')"
    />

    <form-group-timeout v-show="wants('timeout')"
      namespace="timeout"
      :column-label="$i18n.t('Timeout')"
      :text="$i18n.t('Maximum amount of time this task can run.')"
    />

    <form-group-window v-show="wants('window')"
      namespace="window"
      :column-label="$i18n.t('Window')"
      :text="$i18n.t('Window to apply the job to. In the case of a deletion, setting this to 7 days would delete affected data older than 7 days.')"
    />

    <form-group-history-batch v-show="wants('history_batch')"
      namespace="history_batch"
      :column-label="$i18n.t('History Batch')"
      :text="$i18n.t('Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached.')"
    />

    <form-group-history-timeout v-show="wants('history_timeout')"
      namespace="history_timeout"
      :column-label="$i18n.t('History Timeout')"
      :text="$i18n.t('Maximum amount of time this task can run.')"
    />

    <form-group-history-window v-show="wants('history_window')"
      namespace="history_window"
      :column-label="$i18n.t('History Window')"
      :text="$i18n.t('Window to apply the job to. In the case of a deletion, setting this to 7 days would delete affected data older than 7 days.')"
    />

    <form-group-rotate v-show="wants('rotate')"
      namespace="rotate"
      :column-label="$i18n.t('Rotate')"
      :text="$i18n.t(`Enable or disable ${logName} rotation (moving ${logName}_history records to ${logName}_archive)\nIf disabled, this task will delete from the ${logName}_history table rather than the ${logName}_archive.`)"
    />

    <form-group-rotate-batch v-show="wants('rotate_batch')"
      namespace="rotate_batch"
      :column-label="$i18n.t('Rotate Batch')"
      :text="$i18n.t('Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached.')"
    />

    <form-group-rotate-timeout v-show="wants('rotate_timeout')"
      namespace="rotate_timeout"
      :column-label="$i18n.t('Rotate Timeout')"
      :text="$i18n.t('Maximum amount of time this task can run.')"
    />

    <form-group-rotate-window v-show="wants('rotate_window')"
      namespace="rotate_window"
      :column-label="$i18n.t('Rotate Window')"
      :text="$i18n.t('Window to apply the job to. In the case of a deletion, setting this to 7 days would delete affected data older than 7 days.')"
    />

    <form-group-unreg-window v-show="wants('unreg_window')"
      namespace="unreg_window"
      :column-label="$i18n.t('Unreg Window')"
      :text="$i18n.t('How long can a registered node be inactive before it becomes unregistered.')"
    />

    <form-group-delete-window v-show="wants('delete_window')"
      namespace="delete_window"
      :column-label="$i18n.t('Delete Window')"
      :text="$i18n.t(`How long can an unregistered node be inactive before being deleted.\nThis shouldn't be used if you are using port-security.`)"
    />

    <form-group-delay v-show="wants('delay')"
      namespace="delay"
      :column-label="$i18n.t('Delay')"
      :text="$i18n.t('Minimum gap before certificate expiration date (will the certificate expires in ...).')"
    />

    <form-group-certificates v-show="wants('certificates')"
      namespace="certificates"
      :column-label="$i18n.t('Certificates')"
      :text="$i18n.t('SSL certificate(s) to monitor. Comma-separated list.')"
    />

    <form-group-process-switchranges v-show="wants('process_switchranges')"
      namespace="process_switchranges"
      :column-label="$i18n.t('Process switchranges')"
      :text="$i18n.t('Whether or not a switch range should be expanded to process each of its IPs.')"
    />

    <form-group-voip v-show="wants('voip')"
      namespace="voip"
      :column-label="$i18n.t('Process switchranges')"
      :text="$i18n.t('Whether or not the VoIP devices should be handled by this maintenance task.')"
    />
  </base-form>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import { pfSchedulesList as schedulesOptions } from '@/globals/pfSchedules'
import schemaFn from '../schema'
import {
  FormGroupBatch,
  FormGroupCertificates,
  FormGroupDelay,
  FormGroupDeleteWindow,
  FormGroupDescription,
  FormGroupHistoryBatch,
  FormGroupHistoryTimeout,
  FormGroupHistoryWindow,
  FormGroupIdentifier,
  FormGroupSchedule,
  FormGroupProcessSwitchranges,
  FormGroupRotate,
  FormGroupRotateBatch,
  FormGroupRotateTimeout,
  FormGroupRotateWindow,
  FormGroupSessionBatch,
  FormGroupSessionTimeout,
  FormGroupSessionWindow,
  FormGroupStatus,
  FormGroupTimeout,
  FormGroupUnregWindow,
  FormGroupVoip,
  FormGroupWindow
} from './'

const components = {
  BaseForm,

  FormGroupBatch,
  FormGroupCertificates,
  FormGroupDelay,
  FormGroupDeleteWindow,
  FormGroupDescription,
  FormGroupHistoryBatch,
  FormGroupHistoryTimeout,
  FormGroupHistoryWindow,
  FormGroupIdentifier,
  FormGroupSchedule,
  FormGroupProcessSwitchranges,
  FormGroupRotate,
  FormGroupRotateBatch,
  FormGroupRotateTimeout,
  FormGroupRotateWindow,
  FormGroupSessionBatch,
  FormGroupSessionTimeout,
  FormGroupSessionWindow,
  FormGroupStatus,
  FormGroupTimeout,
  FormGroupUnregWindow,
  FormGroupVoip,
  FormGroupWindow
}

export const props = {
  id: {
    type: String
  },
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

  const {
    id,
    meta
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const wanted = computed(() => {
    return [...(new Set(Object.keys(meta.value)))].sort((a, b) => a.localeCompare(b))
  })

  const wants = (key) => wanted.value.includes(key)

  const logName = computed(() => {
    switch (id.value) {
      case 'ip4log_cleanup':
        return 'ip4log' // break
      case 'ip6log_cleanup':
        return 'ip6log' // break
      default:
        return 'log'
    }
  })

  return {
    schema,
    wants,
    logName,
    schedulesOptions
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

