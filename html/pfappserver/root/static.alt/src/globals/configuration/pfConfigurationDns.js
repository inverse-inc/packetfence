import i18n from '@/utils/locale'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'

export const pfConfigurationDnsViewFields = (context = {}) => {
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Record dns requests and replies in SQL tables'),
          text: i18n.t('Record dns requests and replies in the SQL tables.'),
          fields: [
            {
              key: 'record_dns_in_sql',
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
