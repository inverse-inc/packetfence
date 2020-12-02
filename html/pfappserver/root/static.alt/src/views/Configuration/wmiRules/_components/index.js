import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupTextarea
} from '@/components/new/'
import {
  BaseFormGroupToggleZeroOneAsOffOn
} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem            as BaseView,
  BaseFormButtonBar                 as FormButtonBar,

  BaseFormGroupTextarea             as FormGroupAction,
  BaseFormGroupInput                as FormGroupIdentifier,
  BaseFormGroupInput                as FormGroupNamespace,
  BaseFormGroupToggleZeroOneAsOffOn as FormGroupOnTab,
  BaseFormGroupTextarea             as FormGroupRequest,

  TheForm,
  TheView
}
