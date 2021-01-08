import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import BaseFormGroupAcceptUrl from './BaseFormGroupAcceptUrl'
import BaseFormGroupBounce from './BaseFormGroupBounce'
import BaseFormGroupCliAuthorizeRead from './BaseFormGroupCliAuthorizeRead'
import BaseFormGroupCliAuthorizeWrite from './BaseFormGroupCliAuthorizeWrite'
import BaseFormGroupRadiusAttributes from './BaseFormGroupRadiusAttributes'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupRadiusAttributes       as FormGroupAcceptRoles,
  BaseFormGroupAcceptUrl              as FormGroupAcceptUrl,
  BaseFormGroupRadiusAttributes       as FormGroupAcceptVlans,
  BaseFormGroupTextarea               as FormGroupAclTemplate,
  BaseFormGroupBounce                 as FormGroupBounce,
  BaseFormGroupCliAuthorizeRead       as FormGroupCliAuthorizeRead,
  BaseFormGroupCliAuthorizeWrite      as FormGroupCliAuthorizeWrite,
  BaseFormGroupRadiusAttributes       as FormGroupCoa,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupRadiusAttributes       as FormGroupDisconnect,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupNasPortToIfIndex,
  BaseFormGroupChosenOne              as FormGroupRadiusDisconnect,
  BaseFormGroupRadiusAttributes       as FormGroupReject,
  BaseFormGroupToggleDisabledEnabled  as FormGroupSnmpDisconnect,
  BaseFormGroupRadiusAttributes       as FormGroupVoip,

  BaseViewCollectionItem              as BaseView,
  TheForm,
  TheView
}
