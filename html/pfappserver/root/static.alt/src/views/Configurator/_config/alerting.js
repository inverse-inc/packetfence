import store from '@/store'
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '@/views/Configuration/_config'
import {
  isPort,
  emailsCsv
} from '@/globals/pfValidators'
import {
  email
} from 'vuelidate/lib/validators'

export const view = (form = {}, meta = {}) => {
  const {
    alerting: {
      advancedMode = false
    } = {}
  } = meta
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Recipients'),
          text: i18n.t('Comma-separated list of email addresses to which notifications of rogue DHCP servers, violations with an action of email, or any other PacketFence-related message goes to.'),
          cols: [
            {
              namespace: 'alerting.emailaddr',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'alerting.emailaddr'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          if: advancedMode,
          label: i18n.t('Sender'),
          text: i18n.t('Email address from which notifications of rogue DHCP servers, violations with an action of email, or any other PacketFence-related message are sent. Empty means root@<server-domain-name>.'),
          cols: [
            {
              namespace: 'alerting.fromaddr',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'alerting.fromaddr')
            }
          ]
        },
        {
          if: advancedMode,
          label: i18n.t('SMTP server'),
          text: i18n.t(`Server through which to send messages to the above emailaddr. The default is localhost - be sure you're running an SMTP host locally if you don't change it!`),
          cols: [
            {
              namespace: 'alerting.smtpserver',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'alerting.smtpserver')
            }
          ]
        },
        {
          if: advancedMode,
          label: i18n.t('SMTP encryption'),
          text: i18n.t('Encryption style when connecting to the SMTP server.'),
          cols: [
            {
              namespace: 'alerting.smtp_encryption',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'alerting.smtp_encryption')
            }
          ]
        },
        {
          if: advancedMode,
          label: i18n.t('SMTP port'),
          text: i18n.t('The port of the SMTP server. If the port is set to 0 then port is calculated by the encryption type. none: 25, ssl: 465, starttls: 587.'),
          cols: [
            {
              namespace: 'alerting.smtp_port',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'alerting.smtp_port')
            }
          ]
        },
        {
          if: advancedMode,
          label: i18n.t('SMTP username'),
          text: i18n.t('The username used to connect to the SMTP server.'),
          cols: [
            {
              namespace: 'alerting.smtp_username',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'alerting.smtp_username')
            }
          ]
        },
        {
          if: advancedMode,
          label: i18n.t('SMTP password'),
          text: i18n.t('The password used to connect to the SMTP server.'),
          cols: [
            {
              namespace: 'alerting.smtp_password',
              component: pfFormPassword,
              attrs: attributesFromMeta(meta, 'alerting.smtp_password')
            }
          ]
        },
        {
          if: advancedMode,
          label: i18n.t('SMTP Check SSL'),
          text: i18n.t('Verify SSL connection.'),
          cols: [
            {
              namespace: 'alerting.smtp_verifyssl',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: advancedMode,
          label: i18n.t('SMTP timeout'),
          text: i18n.t('The timeout in seconds for sending an email.'),
          cols: [
            {
              namespace: 'alerting.smtp_timeout',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'alerting.smtp_timeout'),
                ...{
                  type: 'number',
                  step: 1
                }
              }
            }
          ]
        },
        {
          label: i18n.t('SMTP test'),
          text: i18n.t('Comma-delimited list of email address(es) to receive test message.'),
          cols: [
            {
              namespace: 'alerting.test_emailaddr',
              component: pfFormInput,
              attrs: {
                test: () => {
                  return store.dispatch('$_bases/testSmtp', { quiet: true, ...form.alerting })
                }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form, meta = {}) => {
  return {
    alerting: {
      emailaddr: {
        ...validatorsFromMeta(meta, 'alerting.emailaddr', i18n.t('Email Addresses')),
        ...{
          [i18n.t('Invalid email address.')]: emailsCsv
        }
      },
      fromaddr: {
        ...validatorsFromMeta(meta, 'alerting.fromaddr', i18n.t('Email')),
        ...{
          [i18n.t('Invalid email address.')]: email
        }
      },
      smtpserver: validatorsFromMeta(meta, 'alerting.smtpserver', i18n.t('Server')),
      // subjectprefix: validatorsFromMeta(meta, 'alerting.subjectprefix', i18n.t('Prefix')),
      smtp_encryption: validatorsFromMeta(meta, 'alerting.smtp_encryption', i18n.t('Encryption')),
      smtp_port: {
        ...validatorsFromMeta(meta, 'alerting.smtp_port', i18n.t('Port')),
        ...{
          [i18n.t('Invalid port.')]: isPort
        }
      },
      smtp_username: validatorsFromMeta(meta, 'alerting.smtp_username', i18n.t('Username')),
      smtp_password: validatorsFromMeta(meta, 'alerting.smtp_password', i18n.t('Password')),
      smtp_timeout: validatorsFromMeta(meta, 'alerting.smtp_timeout', i18n.t('Timeout')),
      test_emailaddr: {
        [i18n.t('Invalid email address.')]: emailsCsv
      }
    }
  }
}
