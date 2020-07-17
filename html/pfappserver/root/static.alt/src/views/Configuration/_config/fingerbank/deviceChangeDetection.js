import i18n from '@/utils/locale'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '../'

export const view = (_, meta = {}) => {
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('Enabled'),
          text: i18n.t('Whether or not the Fingerbank device change feature is enabled.'),
          cols: [
            {
              namespace: 'enable',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Trigger on device class change'),
          text: i18n.t('Whether or not internal::fingerbank_device_change should be triggered when we detect a device class change in Fingerbank.'),
          cols: [
            {
              namespace: 'trigger_on_device_class_change',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Device class change whitelist'),
          text: i18n.t('Which device class changes are allowed in conjunction with trigger_on_device_class_changeComma delimited transitions using the following format: <code>$PREVIOUS_DEVICE_CLASS_ID->$NEW_DEVICE_CLASS_ID</code> where $PREVIOUS_DEVICE_CLASS_ID and $NEW_DEVICE_CLASS_ID are the IDs in the Fingerbank database.'),
          cols: [
            {
              namespace: 'device_class_whitelist',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'device_class_whitelist'),
                ...{
                  rows: 5
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Manual device class change triggers'),
          text: i18n.t('Which changes (changing from a device class to another) should trigger internal::fingerbank_device_change. This setting is independant from trigger_on_device_class_change and allows to specify exactly which transitions should trigger internal::fingerbank_device_change. Comma delimited transitions using the following format: <code>$PREVIOUS_DEVICE_CLASS_ID->$NEW_DEVICE_CLASS_ID</code> where $PREVIOUS_DEVICE_CLASS_ID and $NEW_DEVICE_CLASS_ID are the IDs in the Fingerbank database.'),
          cols: [
            {
              namespace: 'triggers',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'triggers'),
                ...{
                  rows: 5
                }
              }
            }
          ]
        },
        {
          label: null,
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: `<div class="alert alert-info">
                  ${i18n.t('Valid device classes IDs are:')}<br/>
                  <ul>
                    <li><strong>Android OS</strong> = 33453</li>
                    <li><strong>Audio, Imaging or Video Equipment</strong> = 7</li>
                    <li><strong>BlackBerry OS</strong> = 33471</li>
                    <li><strong>Datacenter Appliance</strong> = 23</li>
                    <li><strong>Firewall and Security Appliance</strong> = 33738</li>
                    <li><strong>Gaming Console</strong> = 6</li>
                    <li><strong>Hardware Manufacturer</strong> = 16861</li>
                    <li><strong>Internet of Things (IoT)</strong> = 15</li>
                    <li><strong>iOS</strong> = 33450</li>
                    <li><strong>Linux OS</strong> = 5</li>
                    <li><strong>Mac OS X or macOS</strong> = 2</li>
                    <li><strong>Medical Device</strong> = 8238</li>
                    <li><strong>Monitoring and Testing Device</strong> = 12</li>
                    <li><strong>Network Boot Agent</strong> = 17</li>
                    <li><strong>Operating System</strong> = 16879</li>
                    <li><strong>Phone, Tablet or Wearable</strong> = 11</li>
                    <li><strong>Physical Security</strong> = 22</li>
                    <li><strong>Point of Sale Device</strong> = 24</li>
                    <li><strong>Printer or Scanner</strong> = 8</li>
                    <li><strong>Projector</strong> = 20</li>
                    <li><strong>Robotics and Industrial Automation</strong> = 16842</li>
                    <li><strong>Router, Access Point or Femtocell</strong> = 4</li>
                    <li><strong>Storage Device</strong> = 10</li>
                    <li><strong>Switch and Wireless Controller</strong> = 9</li>
                    <li><strong>Thin Client</strong> = 21</li>
                    <li><strong>Video Conferencing</strong> = 13</li>
                    <li><strong>VoIP Device</strong> = 3</li>
                    <li><strong>Windows OS</strong> = 1</li>
                    <li><strong>Windows Phone OS</strong> = 33507</li>
                  </ul>
                </div>`
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
    device_class_whitelist: validatorsFromMeta(meta, 'device_class_whitelist', i18n.t('Whitelist')),
    triggers: validatorsFromMeta(meta, 'triggers', i18n.t('Triggers'))
  }
}
