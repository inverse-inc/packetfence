import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import { BaseFormGroupIntervalUnit } from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupName,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupInputNumber            as FormGroupPrice,
  BaseFormGroupChosenOne              as FormGroupRole,
  BaseFormGroupIntervalUnit           as FormGroupAccessDuration,
  BaseFormGroupToggleDisabledEnabled  as FormGroupUseTimeBalance,

  TheForm,
  TheView
}
