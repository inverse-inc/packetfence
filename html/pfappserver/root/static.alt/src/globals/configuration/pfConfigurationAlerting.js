import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationAlertingViewFields = (context = {}) => {
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
          label: i18n.t('Recipients'),
          text: i18n.t('Comma-delimited list of email addresses to which notifications of rogue DHCP servers, violations with an action of email, or any other PacketFence-related message goes to.'),
          fields: [
            {
              key: 'emailaddr',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'emailaddr'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'emailaddr', 'Emails')
            }
          ]
        },
        {
          label: i18n.t('Sender'),
          text: i18n.t('Email address from which notifications of rogue DHCP servers, violations with an action of email, or any other PacketFence-related message are sent.Empty means root@<server-domain-name>.'),
          fields: [
            {
              key: 'fromaddr',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'fromaddr'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'fromaddr', 'Email')
            }
          ]
        },
        {
          label: i18n.t('SMTP server'),
          text: i18n.t(`Server through which to send messages to the above emailaddr. The default is localhost - be sure you're running an SMTP host locally if you don't change it!`),
          fields: [
            {
              key: 'smtpserver',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'smtpserver'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'smtpserver', 'Server')
            }
          ]
        },
        {
          label: i18n.t('Subject prefix'),
          text: i18n.t('Subject prefix for email notifications of rogue DHCP servers, violations with an action of email, or any other PacketFence-related message.'),
          fields: [
            {
              key: 'subjectprefix',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'subjectprefix'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'subjectprefix', 'Prefix')
            }
          ]
        },
        {
          label: i18n.t('SMTP encryption'),
          text: i18n.t('Encryption style when connecting to the SMTP server.'),
          fields: [
            {
              key: 'smtp_encryption',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'smtp_encryption'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'smtp_encryption', 'Encryption')
            }
          ]
        },
        {
          label: i18n.t('SMTP port'),
          text: i18n.t('The port of the SMTP server. If the port is set to 0 then port is calculated by the encryption type. none: 25, ssl: 465, starttls: 587.'),
          fields: [
            {
              key: 'smtp_port',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'smtp_port'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'smtp_port', 'Port')
            }
          ]
        },
        {
          label: i18n.t('SMTP username'),
          text: i18n.t('The username used to connect to the SMTP server.'),
          fields: [
            {
              key: 'smtp_username',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'smtp_username'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'smtp_username', 'Username')
            }
          ]
        },
        {
          label: i18n.t('SMTP password'),
          text: i18n.t('The password used to connect to the SMTP server.'),
          fields: [
            {
              key: 'smtp_password',
              component: pfFormPassword,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'smtp_password'),
                ...{
                  test: () => {
                    // TODO #4043
                  }
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'smtp_password', 'Password')
            }
          ]
        },
        {
          label: i18n.t('SMTP Check SSL'),
          text: i18n.t('Verify SSL connection.'),
          fields: [
            {
              key: 'smtp_verifyssl',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('SMTP timeout'),
          text: i18n.t('The timeout in seconds for sending an email.'),
          fields: [
            {
              key: 'smtp_timeout',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'smtp_timeout'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'smtp_timeout', 'Timeout')
            }
          ]
        }
      ]
    }
  ]
}
