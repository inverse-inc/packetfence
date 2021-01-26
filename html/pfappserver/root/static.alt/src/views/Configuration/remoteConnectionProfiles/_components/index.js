import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import BaseFormGroupBasicFilter from './BaseFormGroupBasicFilter'
import BaseFormGroupCondition from '@/views/Configuration/filterEngines/_components/BaseFormGroupCondition'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupToggleDisabledEnabled  as FormGroupStatus,
  BaseFormGroupBasicFilter            as FormGroupBasicFilter,
  BaseFormGroupCondition              as FormGroupAdvancedFilter,
  BaseFormGroupToggleDisabledEnabled  as FormGroupAllowCommunicationSameRole,
  BaseFormGroupChosenMultiple         as FormGroupAllowCommunicationToRoles,
  BaseFormGroupToggleDisabledEnabled  as FormGroupResolveHostnamesOfPeers,
  BaseFormGroupInput                  as FormGroupInternalDomainToResolve,
  BaseFormGroupTextarea               as FormGroupAdditionalDomainsToResolve,
  BaseFormGroupToggleDisabledEnabled  as FormGroupGateway,
  BaseFormGroupTextarea               as FormGroupRoutes,
  BaseFormGroupInput                  as FormGroupStunServer,

  TheForm,
  TheView
}
