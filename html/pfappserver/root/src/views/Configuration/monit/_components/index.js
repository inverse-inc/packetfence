import { BaseViewResource } from '../../_components/new/'
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

  BaseFormGroupTextarea               as FormGroupSender,
  BaseFormGroupTextarea               as FormGroupAlertEmailTo,
  BaseFormGroupInput                  as FormGroupConfigurations,
  BaseFormGroupInput                  as FormGroupMailserver,
  BaseFormGroupSwitch                 as FormGroupStatus,
  BaseFormGroupInput                  as FormGroupSubjectPrefix,

  BaseViewResource as BaseView,
  TheForm,
  TheView
}
