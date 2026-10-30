import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword
} from '@/components/new/'
import BaseFormGroupNetworks from './BaseFormGroupNetworks'
import BaseFormGroupFingerbankEnvironment from './BaseFormGroupFingerbankEnvironment'
import BaseFormGroupInterfaces from './BaseFormGroupInterfaces'
import BaseFormGroupRoutes from './BaseFormGroupRoutes'
import BaseFormGroupDnsServers from './BaseFormGroupDnsServers'
// before TheForm/TheView: they read these bindings at module-eval time
import TabCache from './TabCache'
import TabDevices from './TabDevices'
import TabNetworking from './TabNetworking'
import TabOverview from './TabOverview'
import TabServices from './TabServices'
import TabTroubleshooting from './TabTroubleshooting'
import TheDnsTest from './TheDnsTest'
import TheHostInterfaces from './TheHostInterfaces'
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
  BaseFormGroupInterfaces             as FormGroupInterfaces,
  BaseFormGroupRoutes                 as FormGroupRoutes,
  BaseFormGroupDnsServers             as FormGroupDnsServers,
  BaseFormGroupInput                  as FormGroupHaVip,
  BaseFormGroupInputNumber            as FormGroupHaVrid,
  BaseFormGroupChosenOne              as FormGroupHaInterface,

  TabCache,
  TabDevices,
  TabNetworking,
  TabOverview,
  TabServices,
  TabTroubleshooting,
  TheDnsTest,
  TheHostInterfaces,
  TheForm,
  TheHeader,
  TheView
}
