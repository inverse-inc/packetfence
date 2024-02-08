import {BaseViewCollectionItem} from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupSwitch,
  BaseFormGroupTextarea,
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                         as FormButtonBar,

  BaseFormGroupChosenOne                    as FormGroupAlgorithm,
  BaseFormGroupSwitch                       as FormGroupCoa,
  BaseFormGroupInput                        as FormGroupDescription,
  BaseFormGroupSwitch                       as FormGroupDhcpd,
  BaseFormGroupInput                        as FormGroupDhcpDefaultLeaseTime,
  BaseFormGroupInput                        as FormGroupDhcpEnd,
  BaseFormGroupChosenOne                    as FormGroupDhcpReplyIp,
  BaseFormGroupInput                        as FormGroupDhcpMaxLeaseTime,
  BaseFormGroupInput                        as FormGroupDhcpStart,
  BaseFormGroupInput                        as FormGroupDns,
  BaseFormGroupSwitch                       as FormGroupFakeMacEnabled,
  BaseFormGroupInput                        as FormGroupGateway,
  BaseFormGroupInput                        as FormGroupIdentifier,
  BaseFormGroupTextarea                     as FormGroupIpAssigned,
  BaseFormGroupTextarea                     as FormGroupIpReserved,
  BaseFormGroupSwitch                       as FormGroupNatEnabled,
  BaseFormGroupSwitch                       as FormGroupNatDns,
  BaseFormGroupSwitch                       as FormGroupNetflowAccountingEnabled,
  BaseFormGroupInput                        as FormGroupNetmask,
  BaseFormGroupInput                        as FormGroupNextHop,
  BaseFormGroupChosenOne                    as FormGroupPoolBackend,
  BaseFormGroupInput                        as FormGroupPortalFqdn,
  BaseFormGroupChosenOne                    as FormGroupType,

  BaseViewCollectionItem                    as BaseView,
  TheForm,
  TheView
}
