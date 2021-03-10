<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >

    <form-group-enable namespace="enable"
      :column-label="$i18n.t('Enabled')"
      :text="$i18n.t('Whether or not the Fingerbank device change feature is enabled.')"
    />

    <form-group-trigger-on-device-class-change namespace="trigger_on_device_class_change"
      :column-label="$i18n.t('Trigger on device class change')"
      :text="$i18n.t('Whether or not internal::fingerbank_device_change should be triggered when we detect a device class change in Fingerbank.')"
    />

    <form-group-device-class-whitelist namespace="device_class_whitelist"
      :column-label="$i18n.t('Device class change whitelist')"
      :text="$i18n.t('Which device class changes are allowed in conjunction with trigger_on_device_class_changeComma delimited transitions using the following format: <code>$PREVIOUS_DEVICE_CLASS_ID->$NEW_DEVICE_CLASS_ID</code> where $PREVIOUS_DEVICE_CLASS_ID and $NEW_DEVICE_CLASS_ID are the IDs in the Fingerbank database.')"
    />

    <form-group-triggers namespace="triggers"
      :column-label="$i18n.t('Manual device class change triggers')"
      :text="$i18n.t('Which changes (changing from a device class to another) should trigger internal::fingerbank_device_change. This setting is independant from trigger_on_device_class_change and allows to specify exactly which transitions should trigger internal::fingerbank_device_change. Comma delimited transitions using the following format: <code>$PREVIOUS_DEVICE_CLASS_ID->$NEW_DEVICE_CLASS_ID</code> where $PREVIOUS_DEVICE_CLASS_ID and $NEW_DEVICE_CLASS_ID are the IDs in the Fingerbank database.')"
    />

    <b-row>
      <b-col cols="3"></b-col>
      <b-col cols="9">
        <div class="alert alert-info mr-3">
          <p><strong>{{ $i18n.t('Valid device class IDs:') }}</strong></p>
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
        </div>
      </b-col>
    </b-row>

  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupDeviceClassWhitelist,
  FormGroupEnable,
  FormGroupTriggerOnDeviceClassChange,
  FormGroupTriggers,
} from './'

const components = {
  BaseForm,
  FormGroupDeviceClassWhitelist,
  FormGroupEnable,
  FormGroupTriggerOnDeviceClassChange,
  FormGroupTriggers,
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {

  const schema = computed(() => schemaFn(props))

  return {
    schema
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

