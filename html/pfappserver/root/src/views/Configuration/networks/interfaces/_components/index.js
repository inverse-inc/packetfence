import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupSwitch,
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'
import ToggleStatus from './ToggleStatus'

export {
  BaseViewCollectionItem                    as BaseView,
  BaseFormButtonBar                         as FormButtonBar,

  BaseFormGroupChosenMultiple               as FormGroupAdditionalListeneningDaemons,
  BaseFormGroupSwitch                       as FormGroupCoa,
  BaseFormGroupSwitch                       as FormGroupDhcpdEnabled,
  BaseFormGroupSwitch                       as FormGroupHighAvailability,
  BaseFormGroupInput                        as FormGroupIdentifier,
  BaseFormGroupInput                        as FormGroupIpAddress,
  BaseFormGroupInput                        as FormGroupIpv6Address,
  BaseFormGroupInputNumber                  as FormGroupIpv6Prefix,
  BaseFormGroupSwitch                       as FormGroupNatEnabled,
  BaseFormGroupSwitch                       as FormGroupNatDns,
  BaseFormGroupSwitch                       as FormGroupNetflowAccountingEnabled,
  BaseFormGroupInput                        as FormGroupNetmask,
  BaseFormGroupInput                        as FormGroupRegNetwork,
  BaseFormGroupSwitch                       as FormGroupSplitNetwork,
  BaseFormGroupChosenOne                    as FormGroupType,
  BaseFormGroupInput                        as FormGroupVlan,

  TheForm,
  TheView,
  ToggleStatus
}
