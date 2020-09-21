import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupSelectOne,
  BaseFormGroupTextarea,
  BaseFormGroupToggle,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

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
  BaseFormGroupSelectOne              as FormGroupNtlmCacheSource,
  BaseFormGroupTextarea               as FormGroupNtlmCacheFilter,
  BaseFormGroupInput                  as FormGroupNtlmCacheExpiry,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNtlmCacheBatch,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNtlmCacheBatchOneAtATime,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNtlmCacheOnConnection,

  TheForm,
  TheView
}
