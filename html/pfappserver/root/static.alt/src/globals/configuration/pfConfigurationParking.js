import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationParkingViewFields = (context = {}) => {
  const {
    options: {
      meta = {}
    }
  } = context
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Parking lease length'),
          text: i18n.t('Lease length (in seconds) when a device is in parking.'),
          fields: [
            {
              key: 'lease_length',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'lease_length'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'lease_length', 'Length')
            }
          ]
        },
        {
          label: i18n.t('Parking threshold'),
          text: i18n.t('The threshold (in seconds) after which a device will be placed in parking. A value of 0 deactivates the parking detection. The detection works by looking at the time in seconds a device has been in the registration role and comparing it with this threshold.'),
          fields: [
            {
              key: 'threshold',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'threshold'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'threshold', 'Threshold')
            }
          ]
        },
        {
          label: i18n.t('Place in DHCP parking group'),
          text: i18n.t('Place the device in the DHCP parking group when it is detected doing parking.'),
          fields: [
            {
              key: 'place_in_dhcp_parking_group',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Show parking portal'),
          text: i18n.t('Show the parking portal to the device instead of the usual portal.'),
          fields: [
            {
              key: 'show_parking_portal',
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
