import i18n from '@/utils/locale'
import { pfFieldType as fieldType } from '@/globals/pfField'

export const baseRoles = [
  'registration',
  'isolation'
]

export const importFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [fieldType.SUBSTRING],
    required: true
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [fieldType.SUBSTRING],
    required: true
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [fieldType.SUBSTRING],
    required: false
  },
  {
    value: 'mode',
    text: i18n.t('Mode'),
    types: [fieldType.SUBSTRING],
    required: false
  },
  {
    value: 'group',
    text: i18n.t('Switch Group'),
    types: [fieldType.SUBSTRING],
    required: false
  }
]
