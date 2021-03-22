import { BaseViewResource } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupWaitForRedirect,
  BaseFormGroupTextarea               as FormGroupRange,
  BaseFormGroupToggleDisabledEnabled  as FormGroupPassthrough,
  BaseFormGroupTextarea               as FormGroupPassthroughs,
  BaseFormGroupTextarea               as FormGroupProxyPassthroughs,
  BaseFormGroupToggleDisabledEnabled  as FormGroupIsolationPassthrough,
  BaseFormGroupTextarea               as FormGroupIsolationPassthroughs,
  BaseFormGroupToggleDisabledEnabled  as FormGroupInterceptionProxy,
  BaseFormGroupTextarea               as FormGroupInterceptionProxyPort,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
