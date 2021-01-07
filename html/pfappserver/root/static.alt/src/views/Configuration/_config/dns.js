import i18n from '@/utils/locale'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'

export const view = () => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Record DNS'),
          text: i18n.t('Record DNS requests and replies in the SQL tables.'),
          cols: [
            {
              namespace: 'record_dns_in_sql',
              component: pfFormRangeToggle,
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

export const validators = () => ({})
