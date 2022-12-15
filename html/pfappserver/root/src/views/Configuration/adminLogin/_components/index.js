import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                  as FormButtonBar,

  BaseFormGroupToggleDisabledEnabled as FormGroupAllowUsernamePassword,
  BaseFormGroupInput                 as FormGroupSsoAuthorizePath,
  BaseFormGroupInput                 as FormGroupSsoBaseUrl,
  BaseFormGroupInput                 as FormGroupSsoLoginPath,
  BaseFormGroupInput                 as FormGroupSsoLoginText,
  BaseFormGroupToggleDisabledEnabled as FormGroupSsoStatus,

  BaseViewResource                   as BaseView,
  TheForm,
  TheView
}
