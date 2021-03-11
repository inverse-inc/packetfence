import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputNumber
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
  BaseFormGroupToggleNoYesDefault as FormGroupOcspEnable,
  BaseFormGroupToggleNoYesDefault as FormGroupOcspOverrideCertUrl,
  BaseFormGroupInput              as FormGroupOcspUrl,
  BaseFormGroupToggleNoYesDefault as FormGroupOcspUseNonce,
  BaseFormGroupInputNumber        as FormGroupOcspTimeout,
  BaseFormGroupToggleNoYesDefault as FormGroupOcspSoftfail,

  BaseViewCollectionItem          as BaseView,
  AlertServices,
  TheForm,
  TheView
}
