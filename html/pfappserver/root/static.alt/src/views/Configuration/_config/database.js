import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Hostname'),
          text: i18n.t('Server the mysql server is running on.'),
          cols: [
            {
              namespace: 'host',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'host')
            }
          ]
        },
        {
          label: i18n.t('Port'),
          text: i18n.t('Port the mysql server is running on.'),
          cols: [
            {
              namespace: 'port',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'port')
            }
          ]
        },
        {
          label: i18n.t('Database name'),
          text: i18n.t('Name of the mysql database used by PacketFence.'),
          cols: [
            {
              namespace: 'db',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'db')
            }
          ]
        },
        {
          label: i18n.t('User'),
          text: i18n.t('Username of the account with access to the mysql database used by PacketFence.'),
          cols: [
            {
              namespace: 'user',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'user')
            }
          ]
        },
        {
          label: i18n.t('Password'),
          text: i18n.t('Password for the mysql database used by PacketFence.'),
          cols: [
            {
              namespace: 'pass',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'pass')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  return {
    host: pfConfigurationValidatorsFromMeta(meta, 'host', i18n.t('Host')),
    port: pfConfigurationValidatorsFromMeta(meta, 'port', i18n.t('Port')),
    db: pfConfigurationValidatorsFromMeta(meta, 'db', i18n.t('Database')),
    user: pfConfigurationValidatorsFromMeta(meta, 'user', i18n.t('User')),
    pass: pfConfigurationValidatorsFromMeta(meta, 'user', i18n.t('Password'))
  }
}
