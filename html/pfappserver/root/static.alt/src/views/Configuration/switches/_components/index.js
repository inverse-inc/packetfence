import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber
} from '@/components/new/'
import BaseFormGroupToggleNYDefault from './BaseFormGroupToggleNYDefault'
import BaseFormGroupToggleStaticDynamicDefault from './BaseFormGroupToggleStaticDynamicDefault'
import BaseFormGroupType from './BaseFormGroupType'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                       as FormButtonBar,

  BaseFormGroupToggleNYDefault            as FormGroupCliAccess,
  BaseFormGroupInputNumber                as FormGroupCoaPort,
  BaseFormGroupInput                      as FormGroupControllerIp,
  BaseFormGroupChosenOne                  as FormGroupDeauthenticationMethod,
  BaseFormGroupInput                      as FormGroupDescription,
  BaseFormGroupInput                      as FormGroupDisconnectPort,
  BaseFormGroupToggleNYDefault            as FormGroupExternalPortalEnforcement,
  BaseFormGroupChosenOne                  as FormGroupGroup,
  BaseFormGroupInput                      as FormGroupIdentifier,
  BaseFormGroupChosenOne                  as FormGroupMode,
  BaseFormGroupChosenOne                  as FormGroupTenantIdentifier,
  BaseFormGroupType                       as FormGroupType,
  BaseFormGroupInput                      as FormGroupUplink,
  BaseFormGroupToggleStaticDynamicDefault as FormGroupUplinkDynamic,
  BaseFormGroupToggleNYDefault            as FormGroupUseCoa,
  BaseFormGroupToggleNYDefault            as FormGroupVoipEnabled,
  BaseFormGroupToggleNYDefault            as FormGroupVoipLldpDetect,
  BaseFormGroupToggleNYDefault            as FormGroupVoipCdpDetect,
  BaseFormGroupToggleNYDefault            as FormGroupVoipDhcpDetect,

  TheForm,
  TheView
}

