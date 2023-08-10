import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupSwitch,
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupTextarea               as FormGroupDhcpServers,
  BaseFormGroupInput                  as FormGroupDomain,
  BaseFormGroupInput                  as FormGroupHostname,
  BaseFormGroupSwitch                 as FormGroupSendAnonymousStats,
  BaseFormGroupChosenOne              as FormGroupTimezone,

  BaseViewResource        as BaseView,
  TheForm,
  TheView
}
