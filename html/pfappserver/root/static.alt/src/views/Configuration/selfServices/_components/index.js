import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput
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

  BaseFormGroupInput          as FormGroupIdentifier,
  BaseFormGroupInput          as FormGroupDescription,
  BaseFormGroupIntervalUnit   as FormGroupDeviceRegistrationAccessDuration,
  BaseFormGroupOses           as FormGroupDeviceRegistrationAllowedDevices,
  BaseFormGroupChosenOne      as FormGroupDeviceRegistrationRole,
  BaseFormGroupChosenMultiple as FormGroupRolesAllowedToUnregister,

  TheForm,
  TheView
}
