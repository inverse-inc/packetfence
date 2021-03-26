import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,

  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled,
} from '@/components/new/'
import AlertServices from '../../_components/AlertServices'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupChosenOne              as FormGroupAlgorithm,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupInputNumber            as FormGroupDhcpDefaultLeaseTime,
  BaseFormGroupInputNumber            as FormGroupDhcpMaxLeaseTime,
  BaseFormGroupInput                  as FormGroupDhcpEnd,
  BaseFormGroupInput                  as FormGroupDhcpStart,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupTextarea               as FormGroupIpAssigned,
  BaseFormGroupTextarea               as FormGroupIpReserved,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNetflowAccountingEnabled,
  BaseFormGroupChosenOne              as FormGroupPoolBackend,
  BaseFormGroupInput                  as FormGroupPortalFqdn,

  AlertServices,
  TheForm,
  TheView
}



