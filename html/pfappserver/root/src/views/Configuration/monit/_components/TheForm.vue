<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <div
      class="alert alert-warning"
    >{{ $t(`Modifying this configuration requires to restart monit using the following command: systemctl restart monit`) }}</div>

    <form-group-status namespace="status"
      :column-label="$i18n.t('Status')"
      :text="$i18n.t('Whether or not monit should be enabled on this system.')"
    />

    <form-group-alert-email-to namespace="alert_email_to"
      :column-label="$i18n.t('Alert Email To')"
      :text="$i18n.t('Comma-delimited list of emails addressed who should receive the monit alerts. When left empty, the emails defined in Alerting will receive the alerts.')"
    />

    <form-group-subject-prefix namespace="subject_prefix"
      :column-label="$i18n.t('Subject Prefix')"
      :text="$i18n.t(`Identifier for email alerts that gets added to the subject line of every alert`)"
    />

    <form-group-configurations namespace="configurations"
      :column-label="$i18n.t('Configurations')"
      :text="$i18n.t('Which configurations to generate for monit, active-active will be implicitely added if a cluster configuration is detected')"
    />

    <form-group-mailserver namespace="mailserver"
      :column-label="$i18n.t('Mailserver')"
      :text="$i18n.t('Which mailserver to use for monit. When using localhost, make sure that postfix is properly setup to send or relay emails to the addresses defined in monit.alert_email_to. If this value is left empty, it uses the SMTP settings of the Alerting section.')"
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
  FormGroupAlertEmailTo,
  FormGroupConfigurations,
  FormGroupMailserver,
  FormGroupStatus,
  FormGroupSubjectPrefix
} from './'

const components = {
  BaseForm,

  FormGroupAlertEmailTo,
  FormGroupConfigurations,
  FormGroupMailserver,
  FormGroupStatus,
  FormGroupSubjectPrefix
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

