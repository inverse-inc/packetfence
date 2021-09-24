import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupChosenOne,
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit,
} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupAppId,
  BaseFormGroupInputPassword          as FormGroupAppSecret,
  BaseFormGroupChosenOne              as FormGroupRadiusMfaMethod,
  BaseFormGroupInputPassword          as FormGroupSigningKey,
  BaseFormGroupInputPassword          as FormGroupVerifyKey,
  BaseFormGroupInput                  as FormGroupHost,
  BaseFormGroupInput                  as FormGroupCallbackUrl,
  BaseFormGroupInput                  as FormGroupSplitChar,
  BaseFormGroupIntervalUnit           as FormGroupCacheDuration,

  TheForm,
  TheView
}
