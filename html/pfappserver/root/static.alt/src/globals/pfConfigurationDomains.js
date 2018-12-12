import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/pfConfiguration'
import {
  isFQDN
} from '@/globals/pfValidators'

const {
  required,
  alphaNum
} = require('vuelidate/lib/validators')

export const pfConfigurationDomainsListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Name') }), // re-label
  pfConfigurationListColumns.workgroup
]

export const pfConfigurationDomainsListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Name') }), // re-text
  pfConfigurationListFields.workgroup
]

export const pfConfigurationDomainViewFields = (context = {}) => {
  const { isNew = false, isClone = false } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('Identifier'),
          text: i18n.t('Specify a unique identifier for your configuration.<br/>This doesn\'t have to be related to your domain.'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Name required.')]: required,
                [i18n.t('Alphanumeric characters only.')]: alphaNum
              }
            }
          ]
        },
        {
          label: i18n.t('Workgroup'),
          fields: [
            {
              key: 'workgroup',
              component: pfFormInput,
              validators: {
                [i18n.t('Workgroup required.')]: required
              }
            }
          ]
        },
        {
          label: i18n.t('DNS name of the domain'),
          text: i18n.t('The DNS name (FQDN) of the domain.'),
          fields: [
            {
              key: 'dns_name',
              component: pfFormInput,
              validators: {
                [i18n.t('DNS name required.')]: required,
                [i18n.t('Fully Qualified Domain Name required.')]: isFQDN
              }
            }
          ]
        },
        {
          label: i18n.t('This server\'s name'),
          text: i18n.t('This server\'s name (account name) in your Active Directory. Use \'%h\' to automatically use this server hostname.'),
          fields: [
            {
              key: 'server_name',
              component: pfFormInput,
              validators: {
                [i18n.t('Server name required.')]: required
              }
            }
          ]
        },
        {
          label: i18n.t('Sticky DC'),
          text: i18n.t('This is used to specify a sticky domain controller to connect to. If not specified, default \'*\' will be used to connect to any available domain controller.'),
          fields: [
            {
              key: 'sticky_dc',
              component: pfFormInput,
              validators: {
                [i18n.t('Sticky DC required.')]: required
              }
            }
          ]
        },
        {
          label: i18n.t('Active Directory server'),
          text: i18n.t('The IP address or DNS name of your Active Directory server.'),
          fields: [
            {
              key: 'ad_server',
              component: pfFormInput,
              validators: {
                [i18n.t('Active Directory server required.')]: required
              }
            }
          ]
        },
        {
          label: i18n.t('Username'),
          text: i18n.t('The username of a Domain Admin to use to join the server to the domain.'),
          fields: [
            {
              key: 'bind_dn',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Password'),
          text: i18n.t('The password of a Domain Admin to use to join the server to the domain. Will not be stored permanently and is only used while joining the domain.'),
          fields: [
            {
              key: 'bind_pass',
              component: pfFormInput,
              attrs: {
                type: 'password'
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationDomainViewDefaults = (context = {}) => {
  return {
    id: null,
    ad_server: '%h'
  }
}
