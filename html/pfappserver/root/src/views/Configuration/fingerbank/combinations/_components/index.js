import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputNumber
} from '@/components/new/'
import BaseFormGroupSearchDevices from '../../devices/_components/BaseFormGroupSearch'
import BaseFormGroupSearchDhcpFingerprints from '../../dhcpFingerprints/_components/BaseFormGroupSearch'
import BaseFormGroupSearchDhcpv6Enterprises from '../../dhcpv6Enterprises/_components/BaseFormGroupSearch'
import BaseFormGroupSearchDhcpv6Fingerprints from '../../dhcpv6Fingerprints/_components/BaseFormGroupSearch'
import BaseFormGroupSearchDhcpVendors from '../../dhcpVendors/_components/BaseFormGroupSearch'
import BaseFormGroupSearchMacVendors from '../../macVendors/_components/BaseFormGroupSearch'
import BaseFormGroupSearchUserAgents from '../../userAgents/_components/BaseFormGroupSearch'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                     as FormButtonBar,

  BaseFormGroupInput                    as FormGroupIdentifier,
  BaseFormGroupSearchDevices            as FormGroupDeviceIdentifier,
  BaseFormGroupSearchDhcpFingerprints   as FormGroupDhcpFingerprintIdentifier,
  BaseFormGroupSearchDhcpVendors        as FormGroupDhcpVendorIdentifier,
  BaseFormGroupSearchDhcpv6Enterprises  as FormGroupDhcpv6EnterpriseIdentifier,
  BaseFormGroupSearchDhcpv6Fingerprints as FormGroupDhcpv6FingerprintIdentifier,
  BaseFormGroupSearchMacVendors         as FormGroupMacVendorIdentifier,
  BaseFormGroupSearchUserAgents         as FormGroupUserAgentIdentifier,
  BaseFormGroupInputNumber              as FormGroupScore,
  BaseFormGroupInput                    as FormGroupVersion,

  BaseViewCollectionItem                as BaseView,
  TheForm,
  TheView
}


