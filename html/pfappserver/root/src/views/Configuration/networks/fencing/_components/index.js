import { BaseViewResource } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
BaseFormGroupSwitch,
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupWaitForRedirect,
  BaseFormGroupTextarea               as FormGroupRange,
  BaseFormGroupSwitch                 as FormGroupPassthrough,
  BaseFormGroupTextarea               as FormGroupPassthroughs,
  BaseFormGroupTextarea               as FormGroupProxyPassthroughs,
  BaseFormGroupSwitch                 as FormGroupIsolationPassthrough,
  BaseFormGroupTextarea               as FormGroupIsolationPassthroughs,
  BaseFormGroupSwitch                 as FormGroupInterceptionProxy,
  BaseFormGroupTextarea               as FormGroupInterceptionProxyPort,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
