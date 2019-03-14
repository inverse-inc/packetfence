import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationDatabaseViewFields = (context = {}) => {
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
          label: i18n.t('Hostname'),
          text: i18n.t('Server the mysql server is running on.'),
          fields: [
            {
              key: 'host',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'host'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'host', 'Host')
            }
          ]
        },
        {
          label: i18n.t('Port'),
          text: i18n.t('Port the mysql server is running on.'),
          fields: [
            {
              key: 'port',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'port'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'port', 'Port')
            }
          ]
        },
        {
          label: i18n.t('Database name'),
          text: i18n.t('Name of the mysql database used by PacketFence.'),
          fields: [
            {
              key: 'db',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'db'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'db', 'Database')
            }
          ]
        },
        {
          label: i18n.t('User'),
          text: i18n.t('Username of the account with access to the mysql database used by PacketFence.'),
          fields: [
            {
              key: 'user',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'user'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'user', 'User')
            }
          ]
        },
        {
          label: i18n.t('Password'),
          text: i18n.t('Password for the mysql database used by PacketFence.'),
          fields: [
            {
              key: 'pass',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'pass'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'user', 'Password')
            }
          ]
        }
      ]
    }
  ]
}
