import { BaseViewCollectionItem } from '../../_components/new/'
import BaseFormGroupChosenOneMfa from './BaseFormGroupChosenOneMfa'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupChosenOne,
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupAppId,
  BaseFormGroupInputPassword          as FormGroupAppSecret,
  BaseFormGroupChosenOne              as FormGroupRadiusMfaMethod,

  TheForm,
  TheView
}
