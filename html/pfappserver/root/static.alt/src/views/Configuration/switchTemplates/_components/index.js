import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import BaseFormGroupBounce from './BaseFormGroupBounce'
import BaseFormGroupRadiusAttributes from './BaseFormGroupRadiusAttributes'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupRadiusAttributes       as FormGroupAcceptRoles,
  BaseFormGroupRadiusAttributes       as FormGroupAcceptUrl,
  BaseFormGroupRadiusAttributes       as FormGroupAcceptVlans,
  BaseFormGroupTextarea               as FormGroupAclTemplate,
  BaseFormGroupBounce                 as FormGroupBounce,
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

  BaseViewCollectionItem              as BaseView,
  TheForm,
  TheView
}
