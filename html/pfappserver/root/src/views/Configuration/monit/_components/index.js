import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupTextarea               as FormGroupAlertEmailTo,
  BaseFormGroupInput                  as FormGroupConfigurations,
  BaseFormGroupInput                  as FormGroupMailserver,
  BaseFormGroupToggleDisabledEnabled  as FormGroupStatus,
  BaseFormGroupInput                  as FormGroupSubjectPrefix,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
