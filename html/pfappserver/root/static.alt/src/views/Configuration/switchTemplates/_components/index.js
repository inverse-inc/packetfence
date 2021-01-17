import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import BaseFormGroupRadiusAttributes from './BaseFormGroupRadiusAttributes'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupRadiusAttributes       as FormGroupAcceptRoles,
  BaseFormGroupRadiusAttributes       as FormGroupAcceptUrl,
  BaseFormGroupRadiusAttributes       as FormGroupAcceptVlans,
  BaseFormGroupTextarea               as FormGroupAclTemplate,
  BaseFormGroupRadiusAttributes       as FormGroupBounce,
  BaseFormGroupRadiusAttributes       as FormGroupCliAuthorizeRead,
  BaseFormGroupRadiusAttributes       as FormGroupCliAuthorizeWrite,
  BaseFormGroupRadiusAttributes       as FormGroupCoa,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupRadiusAttributes       as FormGroupDisconnect,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupNasPortToIfIndex,
  BaseFormGroupChosenOne              as FormGroupRadiusDisconnect,
  BaseFormGroupRadiusAttributes       as FormGroupReject,
  BaseFormGroupToggleDisabledEnabled  as FormGroupSnmpDisconnect,
  BaseFormGroupRadiusAttributes       as FormGroupVoip,

  BaseFormGroupToggleDisabledEnabled  as FormGroupWebAuthUseSession,
  BaseFormGroupToggleDisabledEnabled  as FormGroupWebAuthSynchronize,

  BaseFormGroupInput                  as FormGroupWebAuthClientIp,
  BaseFormGroupInput                  as FormGroupWebAuthClientMac,
  BaseFormGroupInput                  as FormGroupWebAuthConnectionType,
  BaseFormGroupInput                  as FormGroupWebAuthGrantUrl,
  BaseFormGroupInput                  as FormGroupWebAuthRedirectUrl,
  BaseFormGroupInput                  as FormGroupWebAuthSSID,
  BaseFormGroupInput                  as FormGroupWebAuthStatusCode,
  BaseFormGroupInput                  as FormGroupWebAuthSwitchId,
  BaseFormGroupInput                  as FormGroupWebAuthSwitchIp,
  BaseFormGroupInput                  as FormGroupWebAuthSwitchMac,

  BaseViewCollectionItem              as BaseView,
  TheForm,
  TheView
}
