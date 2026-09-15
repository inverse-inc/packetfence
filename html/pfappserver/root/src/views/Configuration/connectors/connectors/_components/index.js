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
import TheStatus from './TheStatus' // before TheForm: TheForm reads this binding at module-eval time
import TheHostInterfaces from './TheHostInterfaces' // before TheForm: same reason
import TheEquipment from './TheEquipment' // before TheForm: TheForm reads this binding at module-eval time
import TheCache from './TheCache' // before TheForm: same reason
import TheDnsTest from './TheDnsTest' // before TheForm: same reason
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

  TheForm,
  TheStatus,
  TheHostInterfaces,
  TheEquipment,
  TheCache,
  TheDnsTest,
  TheView
}
