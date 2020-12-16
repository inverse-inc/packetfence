<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('Identification')" active>
        <form-group-identifier namespace="id"
          :column-label="$i18n.t('Identifier')"
          :disabled="!isNew && !isClone"
        />
        <form-group-provider-identifier namespace="Provider_Identifier"
          :column-label="$i18n.t('Provider Identifier')"
        />
        <form-group-location-identifier namespace="Location_Identifier"
          :column-label="$i18n.t('Location Identifier')"
        />
        <form-group-service-provider-brand namespace="Service_Provider_Brand"
          :column-label="$i18n.t('Service Provider Brand')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Location')">
        <form-group-location-type namespace="Location"
          :column-label="$i18n.t('Location')"
        />
        <form-group-sub-location-type namespace="Sub_Location_Type"
          :column-label="$i18n.t('Sub Location Type')"
        />
        <form-group-english-location-name namespace="English_Location_Name"
          :column-label="$i18n.t('English Location Name')"
        />
        <form-group-location-address1 namespace="Location_Address1"
          :column-label="$i18n.t('Location Address1')"
        />
        <form-group-location-address2 namespace="Location_Address2"
          :column-label="$i18n.t('Location Address2')"
        />
        <form-group-english-location-city namespace="English_Location_City"
          :column-label="$i18n.t('English Location City')"
        />
        <form-group-location-zip-postal-code namespace="Location_Zip_Postal_Code"
          :column-label="$i18n.t('Location Zip Postal Code')"
        />
        <form-group-location-state-province-name namespace="Location_State_Province_Name"
          :column-label="$i18n.t('Location State Province Name')"
        />
        <form-group-location-country-name namespace="Location_Country_Name"
          :column-label="$i18n.t('Location Country Name')"
        />
        <form-group-location-phone-number namespace="Location_Phone_Number"
          :column-label="$i18n.t('Location Phone Number')"
        />
        <form-group-location-url namespace="Location_URL"
          :column-label="$i18n.t('Location URL')"
        />
        <form-group-coverage-area namespace="Coverage_Area"
          :column-label="$i18n.t('Coverage Area')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('SSID')">
        <form-group-ssid-open-auth namespace="SSID_Open_Auth"
          :column-label="$i18n.t('SSID Open Auth')"
        />
        <form-group-ssid-broadcasted namespace="SSID_Broadcasted"
          :column-label="$i18n.t('SSID Broadcasted')"
        />
        <form-group-wep-key namespace="WEP_Key"
          :column-label="$i18n.t('WEP Key')"
        />
        <form-group-wep-key-entry-method namespace="WEP_Key_Entry_Method"
          :column-label="$i18n.t('WEP Key Entry Method')"
        />
        <form-group-wep-key-size namespace="WEP_Key_Size"
          :column-label="$i18n.t('WEP Key Size')"
        />
        <form-group-ssid1x namespace="SSID_1X"
          :column-label="$i18n.t('SSID 1X')"
        />
        <form-group-ssid1x-broadcasted namespace="SSID_1X_Broadcasted"
          :column-label="$i18n.t('SSID 1X Broadcasted')"
        />
        <form-group-security-protocol1x namespace="Security_Protocol_1X"
          :column-label="$i18n.t('Security Protocol 1X')"
        />
        <form-group-restricted-access namespace="Restricted_Access"
          :column-label="$i18n.t('Restricted Access')"
        />
        <form-group-client-support namespace="Client_Support"
          :column-label="$i18n.t('Client Support')"
        />
        <form-group-mac-address namespace="MAC_Address"
          :column-label="$i18n.t('MAC Address')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Hours')">
        <form-group-utc-timezone namespace="UTC_Timezone"
          :column-label="$i18n.t('UTC Timezone')"
        />
        <form-group-open-monday namespace="Open_Monday"
          :column-label="$i18n.t('Open Monday')"
        />
        <form-group-open-tuesday namespace="Open_Tuesday"
          :column-label="$i18n.t('Open Tuesday')"
        />
        <form-group-open-wednesday namespace="Open_Wednesday"
          :column-label="$i18n.t('Open Wednesday')"
        />
        <form-group-open-thursday namespace="Open_Thursday"
          :column-label="$i18n.t('Open Thursday')"
        />
        <form-group-open-friday namespace="Open_Friday"
          :column-label="$i18n.t('Open Friday')"
        />
        <form-group-open-saturday namespace="Open_Saturday"
          :column-label="$i18n.t('Open Saturday')"
        />
        <form-group-open-sunday namespace="Open_Sunday"
          :column-label="$i18n.t('Open Sunday')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Longitude/Latitude')">
        <form-group-longitude namespace="Longitude"
          :column-label="$i18n.t('Longitude')"
        />
        <form-group-latitude namespace="Latitude"
          :column-label="$i18n.t('Latitude')"
        />
      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupProviderIdentifier,
  FormGroupLocationIdentifier,
  FormGroupServiceProviderBrand,
  FormGroupLocationType,
  FormGroupSubLocationType,
  FormGroupEnglishLocationName,
  FormGroupLocationAddress1,
  FormGroupLocationAddress2,
  FormGroupEnglishLocationCity,
  FormGroupLocationZipPostalCode,
  FormGroupLocationStateProvinceName,
  FormGroupLocationCountryName,
  FormGroupLocationPhoneNumber,
  FormGroupLocationUrl,
  FormGroupCoverageArea,
  FormGroupSsidOpenAuth,
  FormGroupSsidBroadcasted,
  FormGroupWepKey,
  FormGroupWepKeyEntryMethod,
  FormGroupWepKeySize,
  FormGroupSsid1x,
  FormGroupSsid1xBroadcasted,
  FormGroupSecurityProtocol1x,
  FormGroupRestrictedAccess,
  FormGroupClientSupport,
  FormGroupMacAddress,
  FormGroupUtcTimezone,
  FormGroupOpenMonday,
  FormGroupOpenTuesday,
  FormGroupOpenWednesday,
  FormGroupOpenThursday,
  FormGroupOpenFriday,
  FormGroupOpenSaturday,
  FormGroupOpenSunday,
  FormGroupLongitude,
  FormGroupLatitude
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupProviderIdentifier,
  FormGroupLocationIdentifier,
  FormGroupServiceProviderBrand,
  FormGroupLocationType,
  FormGroupSubLocationType,
  FormGroupEnglishLocationName,
  FormGroupLocationAddress1,
  FormGroupLocationAddress2,
  FormGroupEnglishLocationCity,
  FormGroupLocationZipPostalCode,
  FormGroupLocationStateProvinceName,
  FormGroupLocationCountryName,
  FormGroupLocationPhoneNumber,
  FormGroupLocationUrl,
  FormGroupCoverageArea,
  FormGroupSsidOpenAuth,
  FormGroupSsidBroadcasted,
  FormGroupWepKey,
  FormGroupWepKeyEntryMethod,
  FormGroupWepKeySize,
  FormGroupSsid1x,
  FormGroupSsid1xBroadcasted,
  FormGroupSecurityProtocol1x,
  FormGroupRestrictedAccess,
  FormGroupClientSupport,
  FormGroupMacAddress,
  FormGroupUtcTimezone,
  FormGroupOpenMonday,
  FormGroupOpenTuesday,
  FormGroupOpenWednesday,
  FormGroupOpenThursday,
  FormGroupOpenFriday,
  FormGroupOpenSaturday,
  FormGroupOpenSunday,
  FormGroupLongitude,
  FormGroupLatitude
}

export const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
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

