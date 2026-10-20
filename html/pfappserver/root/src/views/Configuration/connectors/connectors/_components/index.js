import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputPassword
} from '@/components/new/'
import BaseFormGroupNetworks from './BaseFormGroupNetworks'
import BaseFormGroupFingerbankEnvironment from './BaseFormGroupFingerbankEnvironment'
// before TheForm/TheView: they read these bindings at module-eval time
import TabDevices from './TabDevices'
import TabNetworking from './TabNetworking'
import TabOverview from './TabOverview'
import TabTroubleshooting from './TabTroubleshooting'
import TheHeader from './TheHeader'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupInputPassword          as FormGroupSecret,
  BaseFormGroupNetworks               as FormGroupNetworks,
  BaseFormGroupFingerbankEnvironment  as FormGroupFingerbankEnvironment,

  TabDevices,
  TabNetworking,
  TabOverview,
  TabTroubleshooting,
  TheForm,
  TheHeader,
  TheView
}
