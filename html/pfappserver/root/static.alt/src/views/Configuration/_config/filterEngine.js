/* eslint-disable camelcase */
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'

export const columns = [
  {
    key: 'status',
    label: i18n.t('Enabled'),
    sortable: true,
    visible: true
  },
  {
    key: 'id',
    label: i18n.t('Name'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'role',
    label: i18n.t('Role'),
    sortable: true,
    visible: true
  },
  {
    key: 'scopes',
    label: i18n.t('Scopes'),
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
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Name'),
          text: i18n.t('Specify a unique name for your fitler.'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Role'),
          cols: [
            {
              namespace: 'role',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'role')
            }
          ]
        },
        {
          label: i18n.t('Scopes'),
          cols: [
            {
              namespace: 'scopes',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'scopes')
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
    id: {
      ...validatorsFromMeta(meta, 'id', 'Name'),
      ...{
        // [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasDomains, domainExists))
      }
    },
    role: validatorsFromMeta(meta, 'role', i18n.t('Role')),
    scopes: validatorsFromMeta(meta, 'scopes', i18n.t('Scopes'))
  }
}
