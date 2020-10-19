import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupTextarea,
  BaseFormGroupToggle,
  BaseFormGroupToggleNoYes
} from '@/components/new/'
import BaseFormGroupAdministrationRules from './BaseFormGroupAdministrationRules'
import BaseFormGroupAuthenticationRules from './BaseFormGroupAuthenticationRules'
import BaseFormGroupHostPortEncryption from './BaseFormGroupHostPortEncryption'
import BaseFormGroupActiveDirectoryPasswordTest from './BaseFormGroupActiveDirectoryPasswordTest'
import BaseFormGroupIntervalUnit from './BaseFormGroupIntervalUnit'
import BaseFormGroupProtocolHostPort from './BaseFormGroupProtocolHostPort'

import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                         as FormButtonBar,

  BaseFormGroupInput                        as FormGroupActivationDomain,
  BaseFormGroupAdministrationRules          as FormGroupAdministrationRules,
  BaseFormGroupTextarea                     as FormGroupAllowedDomains,
  BaseFormGroupToggleNoYes                  as FormGroupAllowLocaldomain,
  BaseFormGroupInput                        as FormGroupApiKey,
  BaseFormGroupInput                        as FormGroupAuthenticateRealm,
  BaseFormGroupAuthenticationRules          as FormGroupAuthenticationRules,
  BaseFormGroupChosenOne                    as FormGroupAuthorizationSourceIdentifier,
  BaseFormGroupTextarea                     as FormGroupBannedDomains,
  BaseFormGroupInput                        as FormGroupBaseDn,
  BaseFormGroupInput                        as FormGroupBindDn,
  BaseFormGroupToggle                       as FormGroupCacheMatch,
  BaseFormGroupInputNumber                  as FormGroupConnectionTimeout,
  BaseFormGroupToggleNoYes                  as FormGroupCreateLocalAccount,
  BaseFormGroupInput                        as FormGroupDescription,
  BaseFormGroupIntervalUnit                 as FormGroupEmailActivationTimeout,
  BaseFormGroupInput                        as FormGroupEmailAttribute,
  BaseFormGroupChosenOne                    as FormGroupHashPasswords,
  BaseFormGroupInput                        as FormGroupHost,
  BaseFormGroupHostPortEncryption           as FormGroupHostPortEncryption,
  BaseFormGroupInput                        as FormGroupIdentifier,
  BaseFormGroupInput                        as FormGroupIdentityProviderCaCertPath,
  BaseFormGroupInput                        as FormGroupIdentityProviderCertPath,
  BaseFormGroupInput                        as FormGroupIdentityProviderEntityIdentifier,
  BaseFormGroupInput                        as FormGroupIdentityProviderMetadataPath,
  BaseFormGroupInputNumber                  as FormGroupLocalAccountLogins,
  BaseFormGroupTextarea                     as FormGroupMessage,
  BaseFormGroupToggle                       as FormGroupMonitor,
  BaseFormGroupTextarea                     as FormGroupOptions,
  BaseFormGroupActiveDirectoryPasswordTest  as FormGroupPassword,
  BaseFormGroupInput                        as FormGroupPasswordEmailUpdate,
  BaseFormGroupChosenOne                    as FormGroupPasswordLength,
  BaseFormGroupChosenOne                    as FormGroupPasswordRotation,
  BaseFormGroupInput                        as FormGroupPath,
  BaseFormGroupInputNumber                  as FormGroupPinCodeLength,
  BaseFormGroupInputNumber                  as FormGroupPort,
  BaseFormGroupProtocolHostPort             as FormGroupProtocolHostPort,
  BaseFormGroupInputNumber                  as FormGroupReadTimeout,
  BaseFormGroupChosenMultiple               as FormGroupRealms,
  BaseFormGroupChosenOne                    as FormGroupScope,
  BaseFormGroupChosenMultiple               as FormGroupSearchAttributes,
  BaseFormGroupInput                        as FormGroupSearchAttributesAppend,
  BaseFormGroupInputPassword                as FormGroupSecret,
  BaseFormGroupInput                        as FormGroupServiceProviderEntityIdentifier,
  BaseFormGroupInput                        as FormGroupServiceProviderCertPath,
  BaseFormGroupInput                        as FormGroupServiceProviderKeyPath,
  BaseFormGroupToggle                       as FormGroupShuffle,
  BaseFormGroupInput                        as FormGroupTimeout,
  BaseFormGroupChosenOne                    as FormGroupUsernameAttribute,
  BaseFormGroupInputNumber                  as FormGroupWriteTimeout,

  TheForm,
  TheView
}
