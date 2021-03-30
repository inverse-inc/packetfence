import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const columns = [
  {
    key: 'id',
    class: 'text-nowrap',
    label: i18n.t('Identifier'),
    required: true,
    sortable: true,
    visible: true,
    searchable: true
  },
  {
    key: 'name',
    label: i18n.t('Name'),
    sortable: true,
    visible: true,
    searchable: true
  },
  {
    key: 'domain_name',
    label: i18n.t('Domain name'),
    sortable: true,
    visible: true,
    searchable: true
  },
  {
    key: 'portal_domain_name',
    label: i18n.t('Portal domain name'),
    sortable: true,
    visible: true,
    searchable: true
  },
  {
    key: 'buttons',
    locked: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'name',
    text: i18n.t('Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'domain_name',
    text: i18n.t('Domain name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'portal_domain_name',
    text: i18n.t('Portal domain name'),
    types: [conditionType.SUBSTRING]
  }
]
