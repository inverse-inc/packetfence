import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/pfConfiguration'

const {
  required,
  alphaNum
} = require('vuelidate/lib/validators')

export const pfConfigurationRealmsListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Name') }), // re-label
  pfConfigurationListColumns.portal_strip_username,
  pfConfigurationListColumns.admin_strip_username,
  pfConfigurationListColumns.radius_strip_username
]

export const pfConfigurationRealmsListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Name') }) // re-text
]

export const pfConfigurationRealmViewFields = (context = {}) => {
  const { isNew = false, isClone = false, domains = [] } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('Realm'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Realm required.')]: required,
                [i18n.t('Alphanumeric characters only.')]: alphaNum
              }
            }
          ]
        },
        {
          label: i18n.t('Realm Options'),
          text: i18n.t('You can add FreeRADIUS options in the realm definition.'),
          fields: [
            {
              key: 'options',
              component: pfFormTextarea
            }
          ]
        },
        {
          label: i18n.t('Domain'),
          text: i18n.t('The domain to use for the authentication in that realm.'),
          fields: [
            {
              key: 'domain',
              component: pfFormSelect,
              attrs: {
                options: domains
              }
            }
          ]
        },
        {
          label: i18n.t('Strip on the portal'),
          text: i18n.t('Should the usernames matching this realm be stripped when used on the captive portal.'),
          fields: [
            {
              key: 'portal_strip_username',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Strip on the admin'),
          text: i18n.t('Should the usernames matching this realm be stripped when used on the administration interface.'),
          fields: [
            {
              key: 'admin_strip_username',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Strip in RADIUS authorization'),
          text: i18n.t('Should the usernames matching this realm be stripped when used in the authorization phase of 802.1x.' +
            ' Note that this doesn\'t control the stripping in FreeRADIUS, use the options above for that.'),
          fields: [
            {
              key: 'radius_strip_username',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationRealmViewDefaults = (context = {}) => {
  return {
    id: null,
    portal_strip_username: 'enabled',
    admin_strip_username: 'enabled',
    radius_strip_username: 'enabled'
  }
}
