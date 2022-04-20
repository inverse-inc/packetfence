import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit,
  BaseFormGroupOses
} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem      as BaseView,
  BaseFormButtonBar           as FormButtonBar,

  BaseFormGroupInput                 as FormGroupIdentifier,
  BaseFormGroupInput                 as FormGroupDescription,
  BaseFormGroupIntervalUnit          as FormGroupDeviceRegistrationAccessDuration,
  BaseFormGroupOses                  as FormGroupDeviceRegistrationAllowedDevices,
  BaseFormGroupChosenMultiple        as FormGroupDeviceRegistrationRoles,
  BaseFormGroupChosenMultiple        as FormGroupRolesAllowedToUnregister,
  BaseFormGroupToggleDisabledEnabled as FormGroupDynamicPreSharedKey,
  TheForm,
  TheView
}
