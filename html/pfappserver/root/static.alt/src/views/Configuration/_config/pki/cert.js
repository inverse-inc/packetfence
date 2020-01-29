import store from '@/store'
import countries from '@/globals/countries'
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  and,
  not,
  conditional,
  hasPkiCerts,
  pkiCertCnExists
} from '@/globals/pfValidators'
import {
  email,
  required,
  maxLength
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'ID',
    label: i18n.t('Identifier'),
    required: true,
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
    key: 'cn',
    label: i18n.t('Common Name'),
    sortable: true,
    visible: true
  },
  {
    key: 'mail',
    label: i18n.t('Email'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const download = (id, password, filename='cert.p12') => {
  return new Promise((resolve, reject) => {
    store.dispatch('$_pkis/downloadCert', { id, password }).then(arrayBuffer => {
      const blob = new Blob([arrayBuffer], { type: 'application/x-pkcs12' })
      if (window.navigator.msSaveOrOpenBlob) {
        window.navigator.msSaveBlob(blob, filename)
      } else {
        let elem = window.document.createElement('a')
        elem.href = window.URL.createObjectURL(blob)
        elem.download = filename
        document.body.appendChild(elem)
        elem.click()
        document.body.removeChild(elem)
      }
      resolve()
    }).catch(e => {
      reject(e)
    })
  })
}

export const view = (form = {}, meta = {}) => {
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
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: Object.keys(countries).map(countryCode => {
                  return { value: countryCode, text: countries[countryCode] }
                })
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
      [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasPkiCerts, pkiCertCnExists)),
      [i18n.t('Maximum 64 characters.')]: maxLength(64)
    },
    mail: {
      [i18n.t('Invalid email address.')]: email
    },
    organisation: {
      [i18n.t('Maximum 64 characters.')]: maxLength(64)
    },
    state: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    locality: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    street_address: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    postal_code: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    }
  }
}
