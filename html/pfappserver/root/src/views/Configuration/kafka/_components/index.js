import {BaseViewResource} from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled,
} from '@/components/new/'
import BaseFormGroupClusterConfig from './BaseFormGroupClusterConfig'
import BaseFormGroupHostConfigs from './BaseFormGroupHostConfigs'
import BaseFormGroupAuths from './BaseFormGroupAuths'
import BaseFormGroupIptables from './BaseFormGroupIptables'
import BaseFormGroupChosenOneCa from './BaseFormGroupChosenOneCa'
import ButtonKafkaGenerateCertComponent from './ButtonKafkaGenerateCert'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar as FormButtonBar,

  BaseFormGroupInputPassword  as FormGroupAdminPass,
  BaseFormGroupInput          as FormGroupAdminUser,
  BaseFormGroupClusterConfig  as FormGroupClusterConfig,
  BaseFormGroupHostConfigs    as FormGroupHostConfigs,
  BaseFormGroupAuths          as FormGroupAuths,
  BaseFormGroupIptables       as FormGroupIptables,

  BaseFormGroupToggleDisabledEnabled as FormGroupSslEnabled,
  BaseFormGroupChosenOneCa           as FormGroupSslCa,
  BaseFormGroupInput                 as FormGroupSslInput,
  BaseFormGroupTextarea              as FormGroupSslPeerCa,
  ButtonKafkaGenerateCertComponent   as ButtonKafkaGenerateCert,

  BaseViewResource as BaseView,
  TheForm,
  TheView
}
