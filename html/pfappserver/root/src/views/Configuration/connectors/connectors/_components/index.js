import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputPassword
} from '@/components/new/'
import BaseFormGroupNetworks from './BaseFormGroupNetworks'
import BaseFormGroupFingerbankEnvironment from './BaseFormGroupFingerbankEnvironment'
import TheStatus from './TheStatus' // before TheForm: TheForm reads this binding at module-eval time
import TheEquipment from './TheEquipment' // before TheForm: TheForm reads this binding at module-eval time
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

  TheForm,
  TheStatus,
  TheEquipment,
  TheView
}
