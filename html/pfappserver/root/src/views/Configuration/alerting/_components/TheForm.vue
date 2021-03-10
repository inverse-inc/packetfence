<template>
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

    <form-group-from-addr namespace="fromaddr"
      :column-label="$i18n.t('Sender')"
      :text="$i18n.t('Email address from which notifications of rogue DHCP servers, violations with an action of email, or any other PacketFence-related message are sent. Empty means root@<server-domain-name>.')"
    />

    <form-group-smtp-server namespace="smtpserver"
      :column-label="$i18n.t('SMTP server')"
      :text="$i18n.t(`Server through which to send messages to the above emailaddr. The default is localhost - be sure you're running an SMTP host locally if you don't change it!`)"
    />

    <form-group-subject-prefix namespace="subjectprefix"
      :column-label="$i18n.t('Subject prefix')"
      :text="$i18n.t('Subject prefix for email notifications of rogue DHCP servers, violations with an action of email, or any other PacketFence-related message.')"
    />

    <form-group-smtp-encryption namespace="smtp_encryption"
      :column-label="$i18n.t('SMTP encryption')"
      :text="$i18n.t('Encryption style when connecting to the SMTP server.')"
    />

    <form-group-smtp-port namespace="smtp_port"
      :column-label="$i18n.t('SMTP port')"
      :text="$i18n.t('The port of the SMTP server. If the port is set to 0 then port is calculated by the encryption type. none: 25, ssl: 465, starttls: 587.')"
    />

    <form-group-smtp-username namespace="smtp_username"
      :column-label="$i18n.t('SMTP username')"
      :text="$i18n.t('The username used to connect to the SMTP server.')"
    />

    <form-group-smtp-password namespace="smtp_password"
      :column-label="$i18n.t('SMTP password')"
      :text="$i18n.t('The password used to connect to the SMTP server.')"
    />

    <form-group-smtp-verify-ssl namespace="smtp_verifyssl"
      :column-label="$i18n.t('SMTP Check SSL')"
      :text="$i18n.t('Verify SSL connection.')"
    />

    <form-group-smtp-timeout namespace="smtp_timeout"
      :column-label="$i18n.t('SMTP timeout')"
      :text="$i18n.t('The timeout in seconds for sending an email.')"
    />

    <form-group-test-email-addr namespace="test_emailaddr"
      :column-label="$i18n.t('SMTP test')"
      :text="$i18n.t('Comma-delimited list of email address(es) to receive test message.')"
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
} from './'

const components = {
  BaseForm,

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

