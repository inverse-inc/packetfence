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
  hasPkiProfiles,
  pkiProfileNameExists
} from '@/globals/pfValidators'
import {
  email,
  required,
  minValue,
  maxLength
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
    key: 'name',
    label: i18n.t('Name'),
    sortable: true,
    visible: true
  },
  {
    key: 'ca_name',
    label: i18n.t('Certificate Authority'),
    sortable: true,
    visible: true
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
    cas = []
  } = meta
  return [
    {
      tab: i18n.t('General'),
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
          label: i18n.t('Certificate Authority'),
          cols: [
            {
              namespace: 'ca_id',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: cas.map(ca => { return { value: ca.ID.toString(), text: ca.cn } })
              }
            }
          ]
        },
        {
          label: i18n.t('Name'),
          text: i18n.t('Profile Name.'),
          cols: [
            {
              namespace: 'name',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Validity'),
          text: i18n.t('Number of days the certificate will be valid.'),
          cols: [
            {
              namespace: 'validity',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone),
                type: 'number'
              }
            }
          ]
        },
        {
          label: i18n.t('Key type'),
          cols: [
            {
              namespace: 'key_type',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: keyTypes
              },
              listeners: {
                select: (event) => {
                  const { value: key_type } = event
                  if (keySizes[key_type].filter(option => { // does key_size exist in new key_type?
                    return option.value === key_size
                  }).length === 0) { // key_size does not exist in new key_type
                    Vue.set(form, 'key_size', null) // clear key_size
                  }
                }
              }
            }
          ]
        },
        {
          if: key_type,
          label: i18n.t('Key size'),
          cols: [
            {
              namespace: 'key_size',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: (key_type in keySizes) ? keySizes[key_type] : []
              }
            }
          ]
        },
        {
          label: i18n.t('Digest'),
          cols: [
            {
              namespace: 'digest',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: digests
              }
            }
          ]
        },
        {
          label: i18n.t('Key usage'),
          text: i18n.t('Optional. One or many of: digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly, decipherOnly.'),
          cols: [
            {
              namespace: 'key_usage',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: keyUsages,
                multiple: true
              }
            }
          ]
        },
        {
          label: i18n.t('Extended key usage'),
          text: i18n.t('Optional. One or many of: serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCodeCom, msCTLSign, msSGC, msEFS, nsSGC.'),
          cols: [
            {
              namespace: 'extended_key_usage',
              component: pfFormChosen,
              attrs: {
                disabled: (!isNew && !isClone),
                options: extendedKeyUsages,
                multiple: true
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('PKCS 12'),
      rows: [
        {
          label: i18n.t('P12 SMTP server'),
          text: i18n.t('IP or FQDN of the SMTP server to relay the email containing the certificate.'),
          cols: [
            {
              namespace: 'p12_smtp_server',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('P12 mail password'),
          text: i18n.t('Email the password of the pkcs12 file.'),
          cols: [
            {
              namespace: 'p12_mail_password',
              component: pfFormRangeToggle,
              attrs: {
                disabled: (!isNew && !isClone),
                values: { checked: '1', unchecked: '0' }
              }
            }
          ]
        },
        {
          label: i18n.t('P12 mail subject'),
          text: i18n.t('Email subject.'),
          cols: [
            {
              namespace: 'p12_mail_subject',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('P12 mail from'),
          text: i18n.t('Sender email address.'),
          cols: [
            {
              namespace: 'p12_mail_from',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('P12 mail header'),
          text: i18n.t('Email header.'),
          cols: [
            {
              namespace: 'p12_mail_header',
              component: pfFormTextarea,
              attrs: {
                disabled: (!isNew && !isClone),
                rows: 10
              }
            }
          ]
        },
        {
          label: i18n.t('P12 mail footer'),
          text: i18n.t('Email footer.'),
          cols: [
            {
              namespace: 'p12_mail_footer',
              component: pfFormTextarea,
              attrs: {
                disabled: (!isNew && !isClone),
                rows: 10
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
    ca_id: {
      [i18n.t('Certificate Authority required.')]: required
    },
    name: {
      [i18n.t('Name required.')]: required,
      [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasPkiProfiles, pkiProfileNameExists)),
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    validity: {
      [i18n.t('Validity required.')]: required,
      [i18n.t('Minimum 1 day(s).')]: minValue(1)
    },
    p12_smtp_server: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    p12_mail_password: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    p12_mail_subject: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    p12_mail_from: {
      [i18n.t('Invalid email address.')]: email,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    }
  }
}
