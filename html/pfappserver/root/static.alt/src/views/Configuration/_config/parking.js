import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'

export const view = (_, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Parking lease length'),
          text: i18n.t('Lease length (in seconds) when a device is in parking.'),
          cols: [
            {
              namespace: 'lease_length',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'lease_length')
            }
          ]
        },
        {
          label: i18n.t('Parking threshold'),
          text: i18n.t('The threshold (in seconds) after which a device will be placed in parking. A value of 0 deactivates the parking detection. The detection works by looking at the time in seconds a device has been in the registration role and comparing it with this threshold.'),
          cols: [
            {
              namespace: 'threshold',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'threshold')
            }
          ]
        },
        {
          label: i18n.t('Place in DHCP parking group'),
          text: i18n.t('Place the device in the DHCP parking group when it is detected doing parking.'),
          cols: [
            {
              namespace: 'place_in_dhcp_parking_group',
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
          cols: [
            {
              namespace: 'show_parking_portal',
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

export const validators = (_, meta = {}) => {
  return {
    lease_length: validatorsFromMeta(meta, 'lease_length', i18n.t('Length')),
    threshold: validatorsFromMeta(meta, 'threshold', i18n.t('Threshold'))
  }
}
