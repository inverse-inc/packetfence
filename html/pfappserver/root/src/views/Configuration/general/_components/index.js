import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import AlertServices from './AlertServices'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar       as FormButtonBar,

  BaseFormGroupTextarea               as FormGroupDhcpServers,
  BaseFormGroupInput                  as FormGroupDomain,
  BaseFormGroupInput                  as FormGroupHostname,
  BaseFormGroupToggleDisabledEnabled  as FormGroupSendAnonymousStats,
  BaseFormGroupChosenOne              as FormGroupTimezone,

  BaseViewResource        as BaseView,
  AlertServices,
  TheForm,
  TheView
}
