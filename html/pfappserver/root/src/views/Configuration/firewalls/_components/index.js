import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInputNumber            as FormGroupCacheTimeout,
  BaseFormGroupToggleDisabledEnabled  as FormGroupCacheUpdates,
  BaseFormGroupChosenMultiple         as FormGroupCategories,
  BaseFormGroupInput                  as FormGroupDefaultRealm,
  BaseFormGroupInput                  as FormGroupDeviceIdentifier,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupNacName,
  BaseFormGroupInput                  as FormGroupNetworks,
  BaseFormGroupInputPassword          as FormGroupPassword,
  BaseFormGroupInputNumber            as FormGroupPort,
  BaseFormGroupChosenOne              as FormGroupTenantId,
  BaseFormGroupChosenOne              as FormGroupTransport,
  BaseFormGroupInput                  as FormGroupUsername,
  BaseFormGroupInput                  as FormGroupUsernameFormat,
  BaseFormGroupInput                  as FormGroupVsys,

  TheForm,
  TheView
}
