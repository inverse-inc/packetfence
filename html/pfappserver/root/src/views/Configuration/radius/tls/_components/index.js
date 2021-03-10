import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput
} from '@/components/new/'
import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  AlertServices,
  BaseFormGroupToggleNoYesDefault
} from '../../_components/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar               as FormButtonBar,

  BaseFormGroupInput              as FormGroupIdentifier,
  BaseFormGroupChosenOne          as FormGroupCertificateProfile,
  BaseFormGroupInput              as FormGroupDhFile,
  BaseFormGroupInput              as FormGroupCaPath,
  BaseFormGroupInput              as FormGroupCipherList,
  BaseFormGroupInput              as FormGroupEcdhCurve,
  BaseFormGroupToggleNoYesDefault as FormGroupDisableTlsv12,
  BaseFormGroupChosenOne          as FormGroupOcsp,

  BaseViewCollectionItem          as BaseView,
  AlertServices,
  TheForm,
  TheView
}
