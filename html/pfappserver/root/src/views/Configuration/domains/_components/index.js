import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggle,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import BaseButtonJoin from './BaseButtonJoin'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,
  BaseButtonJoin                      as ButtonJoin,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupWorkgroup,
  BaseFormGroupInput                  as FormGroupDnsName,
  BaseFormGroupInput                  as FormGroupServerName,
  BaseFormGroupInput                  as FormGroupStickyDc,
  BaseFormGroupInput                  as FormGroupAdServer,
  BaseFormGroupInput                  as FormGroupDnsServers,
  BaseFormGroupInput                  as FormGroupOu,
  BaseFormGroupToggle                 as FormGroupNtlmv2Only,
  BaseFormGroupToggle                 as FormGroupRegistration,

  BaseFormGroupToggleDisabledEnabled  as FormGroupNtlmCache,
  BaseFormGroupChosenOne              as FormGroupNtlmCacheSource,
  BaseFormGroupTextarea               as FormGroupNtlmCacheFilter,
  BaseFormGroupInput                  as FormGroupNtlmCacheExpiry,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNtlmCacheBatch,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNtlmCacheBatchOneAtATime,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNtlmCacheOnConnection,

  TheForm,
  TheView
}
