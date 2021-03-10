export const columns = [
  {
    key: 'status',
    label: 'Status', // i18n defer
    visible: true
  },
  {
    key: 'id',
    label: 'Name', // i18n defer
    required: true,
    visible: true
  },
  {
    key: 'description',
    label: 'Description', // i18n defer
    required: true,
    visible: true
  },
  {
    key: 'scopes',
    label: 'Scopes', // i18n defer
    visible: true,
    formatter: (value) => {
      if (value && value.constructor === Array && value.length > 0) {
        return value
      }
      return null // otherwise '[]' is displayed in cell
    }
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]
