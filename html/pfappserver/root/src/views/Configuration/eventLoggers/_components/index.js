import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem      as BaseView,
  BaseFormButtonBar           as FormButtonBar,

  BaseFormGroupInput          as FormGroupIdentifier,
  BaseFormGroupInput          as FormGroupDescription,
  BaseFormGroupInput          as FormGroupHost,
  BaseFormGroupInputNumber    as FormGroupPort,
  BaseFormGroupChosenOne      as FormGroupFacility,
  BaseFormGroupChosenMultiple as FormGroupNamespaces,
  BaseFormGroupChosenOne      as FormGroupPriority,

  TheForm,
  TheView
}
