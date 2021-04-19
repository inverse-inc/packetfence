import {
  BaseViewCollectionItem,
  BaseFormGroupToggleDisabledEnabledDefault
} from '@/views/Configuration/_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupTextarea
} from '@/components/new/'
import BaseFormGroupBasicFilter from './BaseFormGroupBasicFilter'
import BaseFormGroupCondition from '@/views/Configuration/filterEngines/_components/BaseFormGroupCondition'
import TheForm from './TheForm'
import TheView from './TheView'
import ToggleStatus from './ToggleStatus'

export {
  BaseViewCollectionItem                    as BaseView,
  BaseFormButtonBar                         as FormButtonBar,

  BaseFormGroupInput                        as FormGroupIdentifier,
  BaseFormGroupInput                        as FormGroupDescription,
  BaseFormGroupToggleDisabledEnabledDefault as FormGroupStatus,
  BaseFormGroupBasicFilter                  as FormGroupBasicFilter,
  BaseFormGroupCondition                    as FormGroupAdvancedFilter,
  BaseFormGroupToggleDisabledEnabledDefault as FormGroupAllowCommunicationSameRole,
  BaseFormGroupChosenMultiple               as FormGroupAllowCommunicationToRoles,
  BaseFormGroupToggleDisabledEnabledDefault as FormGroupResolveHostnamesOfPeers,
  BaseFormGroupInput                        as FormGroupInternalDomainToResolve,
  BaseFormGroupTextarea                     as FormGroupAdditionalDomainsToResolve,
  BaseFormGroupToggleDisabledEnabledDefault as FormGroupGateway,
  BaseFormGroupToggleDisabledEnabledDefault as FormGroupRbacIpFiltering,
  BaseFormGroupTextarea                     as FormGroupRoutes,
  BaseFormGroupInput                        as FormGroupStunServer,

  TheForm,
  TheView,
  ToggleStatus
}
