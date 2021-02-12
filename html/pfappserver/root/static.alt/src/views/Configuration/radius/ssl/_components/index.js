import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupTextareaUpload
} from '@/components/new/'
import { BaseViewCollectionItem } from '../../../_components/new/'
import { AlertServices } from '../../_components/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar           as FormButtonBar,

  BaseFormGroupInput          as FormGroupIdentifier,
  BaseFormGroupTextareaUpload as FormGroupCert,
  BaseFormGroupTextareaUpload as FormGroupCa,
  BaseFormGroupTextareaUpload as FormGroupKey,
  BaseFormGroupInputPassword  as FormGroupPrivateKeyPassword,
  BaseFormGroupTextareaUpload as FormGroupIntermediate,

  BaseViewCollectionItem      as BaseView,
  AlertServices,
  TheForm,
  TheView
}
