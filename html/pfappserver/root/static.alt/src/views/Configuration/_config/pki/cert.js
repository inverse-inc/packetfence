import Vue from 'vue'
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  and,
  not,
  conditional,
  hasPkiCerts,
  pkiCertCnExists
} from '@/globals/pfValidators'
import {
  required,
  email
} from 'vuelidate/lib/validators'
import {
  digests,
  keyTypes,
  keySizes,
  keyUsages,
  extendedKeyUsages
} from './'

export const columns = [
  {
    key: 'ID',
    label: i18n.t('Identifier'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'cn',
    label: i18n.t('Common Name'),
    sortable: true,
    visible: true
  },
  {
    key: 'ca_profile',
    label: i18n.t('Certificate Authority - Profile'),
    sortable: true,
    visible: true,
    sortByFormatted: true,
    formatter: (value, key, item) => {
      return `${item.ca_name} - ${item.profile_name}`
    }
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const view = (form = {}, meta = {}) => {
  const {
    key_type = null,
    key_size = null,
    cert = null
  } = form
  const {
    isNew = false,
    isClone = false,
    profiles = []
  } = meta
  return [
    {
      tab: null,
      rows: [
        {
          if: (!isNew && !isClone),
          label: i18n.t('Identifier'),
          cols: [
            {
              namespace: 'ID',
              component: pfFormInput,
              attrs: {
                disabled: true
              }
            }
          ]
        },
        {
          label: i18n.t('Certificate Profile'),
          text: i18n.t('Certificate profile used for this certificate.'),
          cols: [
            {
              namespace: 'profile_id',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: profiles.map(profile => { return { value: profile.ID.toString(), text: `${profile.ca_name} - ${profile.name}` } })
              }
            }
          ]
        },
        {
          label: i18n.t('Common Name'),
          text: i18n.t('Username for this certificate.'),
          cols: [
            {
              namespace: 'cn',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Email'),
          text: i18n.t('Email address of the user. The email with the certificate will be sent to this address.'),
          cols: [
            {
              namespace: 'mail',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Organisation'),
          cols: [
            {
              namespace: 'organisation',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Country'),
          cols: [
            {
              namespace: 'country',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('State or Province'),
          cols: [
            {
              namespace: 'state',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Locality'),
          cols: [
            {
              namespace: 'locality',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Street Address'),
          cols: [
            {
              namespace: 'street_address',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Postal Code'),
          cols: [
            {
              namespace: 'postal_code',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    profile_id: {
      [i18n.t('Profile required.')]: required
    },
    cn: {
      [i18n.t('Common Name required.')]: required,
      [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasPkiCerts, pkiCertCnExists))
    },
    mail: {
      [i18n.t('Invalid email address.')]: email
    }
  }
}
