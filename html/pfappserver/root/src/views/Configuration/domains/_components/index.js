import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupFileUpload,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupInputTest,
  BaseFormGroupSwitch,
  BaseFormGroupToggleDisabledEnabled,
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupWorkgroup,
  BaseFormGroupInput                  as FormGroupDnsName,
  BaseFormGroupInput                  as FormGroupServerName,
  BaseFormGroupInput                  as FormGroupStickyDc,
  BaseFormGroupInput                  as FormGroupAdFqdn,
  BaseFormGroupInput                  as FormGroupAdServer,
  BaseFormGroupInput                  as FormGroupDnsServers,
  BaseFormGroupInput                  as FormGroupOu,
  BaseFormGroupInputPassword          as FormGroupMachineAccountPasswordOnly,
  BaseFormGroupInputTest              as FormGroupMachineAccountPassword,
  BaseFormGroupInput                  as FormGroupAdditionalMachineAccounts,
  BaseFormGroupInput                  as FormGroupBindDn,
  BaseFormGroupInputPassword          as FormGroupBindPass,
  BaseFormGroupSwitch                 as FormGroupNtlmv2Only,
  BaseFormGroupSwitch                 as FormGroupUseConnector,
  BaseFormGroupSwitch                 as FormGroupRegistration,

  BaseFormGroupSwitch                 as FormGroupNtlmCache,
  BaseFormGroupChosenOne              as FormGroupNtlmCacheSource,
  BaseFormGroupInput                  as FormGroupNtlmCacheExpiry,

  BaseFormGroupSwitch                 as FormGroupNtKeyCacheEnabled,
  BaseFormGroupInput                  as FormGroupNtKeyCacheExpire,
  BaseFormGroupInput                  as FormGroupAdAccountLockoutThreshold,
  BaseFormGroupInput                  as FormGroupAdAccountLockoutDuration,
  BaseFormGroupInput                  as FormGroupAdResetAccountLockoutCounterAfter,
  BaseFormGroupInput                  as FormGroupAdOldPasswordAllowedPeriod,
  BaseFormGroupInput                  as FormGroupMaxAllowedPasswordAttemptsPerDevice,

  BaseFormGroupToggleDisabledEnabled  as FormGroupChannelBinding,
  BaseFormGroupToggleDisabledEnabled  as FormGroupForceLdap,
  BaseFormGroupChosenOne              as FormGroupEncryption,
  BaseFormGroupFileUpload             as FormGroupClientCertFile,
  BaseFormGroupFileUpload             as FormGroupClientKeyFile,
  BaseFormGroupFileUpload             as FormGroupCaFile,


  TheForm,
  TheView
}
