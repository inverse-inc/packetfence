import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import AlertServices from './AlertServices'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupTextarea               as FormGroupSender,
  BaseFormGroupTextarea               as FormGroupAlertEmailTo,
  BaseFormGroupInput                  as FormGroupConfigurations,
  BaseFormGroupInput                  as FormGroupMailserver,
  BaseFormGroupToggleDisabledEnabled  as FormGroupStatus,
  BaseFormGroupInput                  as FormGroupSubjectPrefix,

  BaseViewResource as BaseView,
  AlertServices,
  TheForm,
  TheView
}
