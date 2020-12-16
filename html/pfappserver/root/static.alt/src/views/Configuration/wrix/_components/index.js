import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenTimezone,
  BaseFormGroupInput,
  BaseFormGroupToggleNY
} from '@/components/new/'
import BaseFormGroupSecurityProtocol1x from './BaseFormGroupSecurityProtocol1x'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupProviderIdentifier,
  BaseFormGroupInput                  as FormGroupLocationIdentifier,
  BaseFormGroupInput                  as FormGroupServiceProviderBrand,
  BaseFormGroupInput                  as FormGroupLocationType,
  BaseFormGroupInput                  as FormGroupSubLocationType,
  BaseFormGroupInput                  as FormGroupEnglishLocationName,
  BaseFormGroupInput                  as FormGroupLocationAddress1,
  BaseFormGroupInput                  as FormGroupLocationAddress2,
  BaseFormGroupInput                  as FormGroupEnglishLocationCity,
  BaseFormGroupInput                  as FormGroupLocationZipPostalCode,
  BaseFormGroupInput                  as FormGroupLocationStateProvinceName,
  BaseFormGroupInput                  as FormGroupLocationCountryName,
  BaseFormGroupInput                  as FormGroupLocationPhoneNumber,
  BaseFormGroupInput                  as FormGroupLocationUrl,
  BaseFormGroupInput                  as FormGroupCoverageArea,
  BaseFormGroupInput                  as FormGroupSsidOpenAuth,
  BaseFormGroupToggleNY               as FormGroupSsidBroadcasted,
  BaseFormGroupInput                  as FormGroupWepKey,
  BaseFormGroupInput                  as FormGroupWepKeyEntryMethod,
  BaseFormGroupInput                  as FormGroupWepKeySize,
  BaseFormGroupInput                  as FormGroupSsid1x,
  BaseFormGroupToggleNY               as FormGroupSsid1xBroadcasted,
  BaseFormGroupSecurityProtocol1x     as FormGroupSecurityProtocol1x,
  BaseFormGroupToggleNY               as FormGroupRestrictedAccess,
  BaseFormGroupInput                  as FormGroupClientSupport,
  BaseFormGroupInput                  as FormGroupMacAddress,
  BaseFormGroupChosenTimezone         as FormGroupUtcTimezone,
  BaseFormGroupInput                  as FormGroupOpenMonday,
  BaseFormGroupInput                  as FormGroupOpenTuesday,
  BaseFormGroupInput                  as FormGroupOpenWednesday,
  BaseFormGroupInput                  as FormGroupOpenThursday,
  BaseFormGroupInput                  as FormGroupOpenFriday,
  BaseFormGroupInput                  as FormGroupOpenSaturday,
  BaseFormGroupInput                  as FormGroupOpenSunday,
  BaseFormGroupInput                  as FormGroupLongitude,
  BaseFormGroupInput                  as FormGroupLatitude,

  TheForm,
  TheView
}
