import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import {
  BaseFormGroupToggleZeroOneIntegerAsOffOn
} from '@/views/Configuration/_components/new/'
import AlertServices from '../../_components/AlertServices'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                         as FormButtonBar,

  BaseFormGroupChosenOne                    as FormGroupAlgorithm,
  BaseFormGroupToggleDisabledEnabled        as FormGroupCoa,
  BaseFormGroupToggleDisabledEnabled        as FormGroupDhcpd,
  BaseFormGroupInput                        as FormGroupDhcpDefaultLeaseTime,
  BaseFormGroupInput                        as FormGroupDhcpEnd,
  BaseFormGroupInput                        as FormGroupDhcpMaxLeaseTime,
  BaseFormGroupInput                        as FormGroupDhcpStart,
  BaseFormGroupInput                        as FormGroupDns,
  BaseFormGroupToggleZeroOneIntegerAsOffOn  as FormGroupFakeMacEnabled,
  BaseFormGroupInput                        as FormGroupGateway,
  BaseFormGroupInput                        as FormGroupIdentifier,
  BaseFormGroupTextarea                     as FormGroupIpAssigned,
  BaseFormGroupTextarea                     as FormGroupIpReserved,
  BaseFormGroupToggleZeroOneIntegerAsOffOn  as FormGroupNatEnabled,
  BaseFormGroupToggleDisabledEnabled        as FormGroupNetflowAccountingEnabled,
  BaseFormGroupInput                        as FormGroupNetmask,
  BaseFormGroupInput                        as FormGroupNextHop,
  BaseFormGroupChosenOne                    as FormGroupPoolBackend,
  BaseFormGroupInput                        as FormGroupPortalFqdn,
  BaseFormGroupChosenOne                    as FormGroupTenantIdentifier,
  BaseFormGroupChosenOne                    as FormGroupType,

  BaseViewCollectionItem                    as BaseView,
  AlertServices,
  TheForm,
  TheView
}
