import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupSwitch,
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                  as FormButtonBar,

  BaseFormGroupSwitch                as FormGroupAllowUsernamePassword,
  BaseFormGroupInput                 as FormGroupSsoAuthorizePath,
  BaseFormGroupInput                 as FormGroupSsoBaseUrl,
  BaseFormGroupInput                 as FormGroupSsoLoginPath,
  BaseFormGroupInput                 as FormGroupSsoLoginText,
  BaseFormGroupSwitch                as FormGroupSsoStatus,

  BaseViewResource                   as BaseView,
  TheForm,
  TheView
}
