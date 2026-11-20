import {BaseViewResource} from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
} from '@/components/new/'
import BaseFormGroupClusterConfig from './BaseFormGroupClusterConfig'
import BaseFormGroupHostConfigs from './BaseFormGroupHostConfigs'
import BaseFormGroupAuths from './BaseFormGroupAuths'
import ButtonServiceKafka from './ButtonServiceKafka'
import BaseFormGroupIptables from './BaseFormGroupIptables'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar as FormButtonBar,

  BaseFormGroupInputPassword  as FormGroupAdminPass,
  BaseFormGroupChosenMultiple as FormGroupBrokerOnlyHosts,
  BaseFormGroupInput          as FormGroupAdminUser,
  BaseFormGroupClusterConfig  as FormGroupClusterConfig,
  BaseFormGroupHostConfigs    as FormGroupHostConfigs,
  BaseFormGroupAuths          as FormGroupAuths,
  BaseFormGroupIptables       as FormGroupIptables,

  BaseViewResource as BaseView,
  ButtonServiceKafka,
  TheForm,
  TheView
}
