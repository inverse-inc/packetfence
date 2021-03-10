import { BaseViewResource } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupToggleDisabledEnabled,
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupUpstreamApiKey,
  BaseFormGroupInput                  as FormGroupUpstreamHost,
  BaseFormGroupInputNumber            as FormGroupUpstreamPort,
  BaseFormGroupToggleDisabledEnabled  as FormGroupUpstreamUseHttps,
  BaseFormGroupInput                  as FormGroupUpstreamDatabasePath,
  BaseFormGroupInputNumber            as FormGroupUpstreamSqliteDatabaseRetention,
  BaseFormGroupInput                  as FormGroupCollectorHost,
  BaseFormGroupInputNumber            as FormGroupCollectorPort,
  BaseFormGroupToggleDisabledEnabled  as FormGroupCollectorUseHttps,
  BaseFormGroupInput                  as FormGroupCollectorInactiveEndpointsExpiration,
  BaseFormGroupToggleDisabledEnabled  as FormGroupCollectorArpLookup,
  BaseFormGroupToggleDisabledEnabled  as FormGroupCollectorNetworkBehaviorAnalysis,
  BaseFormGroupInputNumber            as FormGroupCollectorQueryCacheTime,
  BaseFormGroupInputNumber            as FormGroupCollectorDatabasePersistenceInterval,
  BaseFormGroupInputNumber            as FormGroupCollectorClusterResyncInterval,
  BaseFormGroupToggleDisabledEnabled  as FormGroupQueryRecordUnmatched,
  BaseFormGroupToggleDisabledEnabled  as FormGroupProxyUseProxy,
  BaseFormGroupInput                  as FormGroupProxyHost,
  BaseFormGroupInputNumber            as FormGroupProxyPort,
  BaseFormGroupToggleDisabledEnabled  as FormGroupProxyVerifySsl,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
