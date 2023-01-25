import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupToggleDisabledEnabled  as FormGroupAllLogs,
  BaseFormGroupInput                  as FormGroupHost,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupChosenMultiple         as FormGroupLogs,
  BaseFormGroupInputNumber            as FormGroupPort,
  BaseFormGroupChosenOne              as FormGroupProto,

  TheForm,
  TheView
}
