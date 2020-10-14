import i18n from '@/utils/locale'

export const useInputMultiselectProps = {
  id: {
    type: [Number, String]
  },
  options: {
    type: Array,
    default: () => ([])
  },
  multiple: {
    type: Boolean,
    default: false
  },
  trackBy: {
    type: String,
    default: 'value'
  },
  label: {
    type: String,
    default: 'text'
  },
  searchable: {
    type: Boolean,
    default: true
  },
  clearOnSelect: {
    type: Boolean,
    default: true
  },
  hideSelected: {
    type: Boolean,
    default: false
  },
  allowEmpty: {
    type: Boolean,
    default: true
  },
  resetAfter: {
    type: Boolean,
    default: false
  },
  closeOnSelect: {
    type: Boolean,
    default: true
  },
  customLabel: {
    type: [Function, String]
  },
  taggable: {
    type: Boolean,
    default: false
  },
  tagPlaceholder: {
    type: String,
    default: i18n.t('Press enter to create a tag')
  },
  tagPosition: {
    type: String,
    default: 'top'
  },
  max: {
    type: [Number, String],
    default: 1000
  },
  optionsLimit: {
    type: [Number, String],
    default: 1000
  },
  groupValues: {
    type: String
  },
  groupLabel: {
    type: String
  },
  groupSelect: {
    type: Boolean,
    default: false
  },
  internalSearch: {
    type: Boolean,
    default: false
  },
  preserveSearch: {
    type: Boolean,
    default: true
  },
  preselectFirst: {
    type: Boolean,
    default: false
  },
  name: {
    type: String,
    default: ''
  },
  selectLabel: {
    type: String,
    default: i18n.t('') // Press enter to select
  },
  selectGroupLabel: {
    type: String,
    default: i18n.t('') // Press enter to select group
  },
  selectedLabel: {
    type: String,
    default: i18n.t('') // Selected
  },
  deselectLabel: {
    type: String,
    default: i18n.t('') // Press enter to remove
  },
  deselectGroupLabel: {
    type: String,
    default: i18n.t('') // Press enter to deselect group
  },
  showLabels: {
    type: Boolean,
    default: true
  },
  limit: {
    type: [Number, String],
    default: 1000
  },
  limitText: {
    type: [Function, String],
    default: count => i18n.t('and {count} more', { count })
  },
  openDirection: {
    type: String,
    default: ''
  },
  showPointer: {
    type: Boolean,
    default: true
  }
}
