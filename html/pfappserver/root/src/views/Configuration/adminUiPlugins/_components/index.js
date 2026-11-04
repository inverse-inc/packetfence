import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextareaUpload,
  BaseFormGroupToggleDisabledEnabled,
} from '@/components/new/'
import BaseFormGroupStringArray from '../../plugins/_components/BaseFormGroupStringArray'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupChosenOne              as FormGroupAcl,
  BaseFormGroupStringArray            as FormGroupConfigFiles,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupToggleDisabledEnabled  as FormGroupEnabled,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupTextareaUpload         as FormGroupManifest,
  BaseFormGroupInput                  as FormGroupReplaces,
  BaseFormGroupInput                  as FormGroupUpstream,

  TheForm,
  TheView
}
