<template>
  <b-card no-body>
    <b-card-header>
      <b-row align-h="between" align-v="center">
        <b-col cols="auto" class="mr-auto">
          <h4 class="mb-0">{{ $i18n.t('Alerting') }}</h4>
        </b-col>
        <b-col cols="auto">
          <base-input-toggle-advanced-mode v-model="advancedMode" label-left />
        </b-col>
      </b-row>
    </b-card-header>
    <b-form>
      <base-form
        :form="form"
        :meta="meta"
        :schema="schema"
        :isLoading="isLoading"
      >
        <form-group-email-addr namespace="emailaddr"
          :column-label="$i18n.t('Recipients')"
          :text="$i18n.t('Comma-separated list of email addresses to which notifications of rogue DHCP servers, violations with an action of email, or any other PacketFence-related message goes to.')"
        />

        <form-group-from-addr v-if="advancedMode"
          namespace="fromaddr"
          :column-label="$i18n.t('Sender')"
          :text="$i18n.t('Email address from which notifications of rogue DHCP servers, violations with an action of email, or any other PacketFence-related message are sent. Empty means root@<server-domain-name>.')"
        />

        <form-group-smtp-server v-if="advancedMode"
          namespace="smtpserver"
          :column-label="$i18n.t('SMTP server')"
          :text="$i18n.t(`Server through which to send messages to the above emailaddr. The default is localhost - be sure you're running an SMTP host locally if you don't change it!`)"
        />

        <form-group-smtp-encryption v-if="advancedMode"
          namespace="smtp_encryption"
          :column-label="$i18n.t('SMTP encryption')"
          :text="$i18n.t('Encryption style when connecting to the SMTP server.')"
        />

        <form-group-smtp-port v-if="advancedMode"
          namespace="smtp_port"
          :column-label="$i18n.t('SMTP port')"
          :text="$i18n.t('The port of the SMTP server. If the port is set to 0 then port is calculated by the encryption type. none: 25, ssl: 465, starttls: 587.')"
        />

        <form-group-smtp-username v-if="advancedMode"
          namespace="smtp_username"
          :column-label="$i18n.t('SMTP username')"
          :text="$i18n.t('The username used to connect to the SMTP server.')"
        />

        <form-group-smtp-password v-if="advancedMode"
          namespace="smtp_password"
          :column-label="$i18n.t('SMTP password')"
          :text="$i18n.t('The password used to connect to the SMTP server.')"
        />

        <form-group-smtp-verify-ssl v-if="advancedMode"
          namespace="smtp_verifyssl"
          :column-label="$i18n.t('SMTP Check SSL')"
          :text="$i18n.t('Verify SSL connection.')"
        />

        <form-group-smtp-timeout v-if="advancedMode"
          namespace="smtp_timeout"
          :column-label="$i18n.t('SMTP timeout')"
          :text="$i18n.t('The timeout in seconds for sending an email.')"
        />

        <form-group-test-email-addr namespace="test_emailaddr"
          :column-label="$i18n.t('SMTP test')"
          :text="$i18n.t('Comma-delimited list of email address(es) to receive test message.')"
        />
      </base-form>
    </b-form>
  </b-card>
</template>
<script>
import {
  BaseForm,
  BaseInputToggleAdvancedMode
} from '@/components/new/'
import {
  FormGroupEmailAddr,
  FormGroupFromAddr,
  FormGroupSmtpEncryption,
  FormGroupSmtpPassword,
  FormGroupSmtpPort,
  FormGroupSmtpServer,
  FormGroupSmtpTimeout,
  FormGroupSmtpUsername,
  FormGroupSmtpVerifySsl,
  FormGroupSubjectPrefix,
  FormGroupTestEmailAddr
} from '@/views/Configuration/alerting/_components/'

const components = {
  BaseForm,
  BaseInputToggleAdvancedMode,

  FormGroupEmailAddr,
  FormGroupFromAddr,
  FormGroupSmtpEncryption,
  FormGroupSmtpPassword,
  FormGroupSmtpPort,
  FormGroupSmtpServer,
  FormGroupSmtpTimeout,
  FormGroupSmtpUsername,
  FormGroupSmtpVerifySsl,
  FormGroupSubjectPrefix,
  FormGroupTestEmailAddr
}

import { computed, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import schemaFn from '@/views/Configuration/alerting/schema'

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const advancedMode = ref(false)

  const form = ref({})
  $store.dispatch('$_bases/getAlerting').then(_form => form.value = _form)

  const meta = ref({})
  $store.dispatch('$_bases/optionsAlerting').then(({ meta: _meta }) => meta.value = _meta)

  const schema = computed(() => schemaFn(props))

  const isLoading = computed(() => $store.getters['$_bases/isLoading'])

  const onSave = () => {
    return $store.dispatch('$_bases/updateAlerting', Object.assign({ quiet: true }, form.value)).catch(error => {
      // Only show a notification in case of a failure
      const { response: { data: { message = '' } = {} } = {} } = error
      $store.dispatch('notification/danger', {
        icon: 'exclamation-triangle',
        url: message,
        message: i18n.t('An error occured while updating the alerting configuration.')
      })
      throw error
    })
  }

  return {
    advancedMode,
    form,
    meta,
    schema,
    isLoading,
    onSave
  }
}

// @vue/component
export default {
  name: 'form-alerting',
  inheritAttrs: false,
  components,
  setup
}
</script>

