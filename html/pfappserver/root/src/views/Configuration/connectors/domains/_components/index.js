import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupChosenOne
} from '@/components/new/'
import TheTest from './TheTest' // before TheForm: TheForm reads this binding at module-eval time
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem      as BaseView,
  BaseFormButtonBar           as FormButtonBar,

  BaseFormGroupInput          as FormGroupIdentifier,
  BaseFormGroupChosenOne      as FormGroupConnector,

  TheForm,
  TheTest,
  TheView
}
