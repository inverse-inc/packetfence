import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '@/views/Configuration/_config'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Hostname'),
          text: i18n.t('Server the MySQL server is running on.'),
          cols: [
            {
              namespace: 'database.host',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'database.host')
            }
          ]
        },
        {
          label: i18n.t('Port'),
          text: i18n.t('Port the MySQL server is running on.'),
          cols: [
            {
              namespace: 'database.port',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'database.port')
            }
          ]
        },
        {
          label: i18n.t('Database name'),
          text: i18n.t('Name of the MySQL database used by PacketFence.'),
          cols: [
            {
              namespace: 'database.db',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'database.db')
            }
          ]
        },
        {
          label: i18n.t('User'),
          text: i18n.t('Username of the account with access to the MySQL database used by PacketFence.'),
          cols: [
            {
              namespace: 'database.user',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'database.user')
            }
          ]
        },
        {
          label: i18n.t('Password'),
          text: i18n.t('Password for the MySQL database used by PacketFence.'),
          cols: [
            {
              namespace: 'database.pass',
              component: pfFormPassword,
              attrs: attributesFromMeta(meta, 'database.pass')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  return {
    database: {
      host: validatorsFromMeta(meta, 'database.host', i18n.t('Host')),
      port: validatorsFromMeta(meta, 'database.port', i18n.t('Port')),
      db: validatorsFromMeta(meta, 'database.db', i18n.t('Database')),
      user: validatorsFromMeta(meta, 'database.user', i18n.t('User')),
      pass: validatorsFromMeta(meta, 'database.user', i18n.t('Password'))
    }
  }
}
