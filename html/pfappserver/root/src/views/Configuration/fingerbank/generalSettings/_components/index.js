import { BaseViewResource } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea,
  BaseFormGroupSwitch,
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupUpstreamApiKey,
  BaseFormGroupInput                  as FormGroupUpstreamHost,
  BaseFormGroupInputNumber            as FormGroupUpstreamPort,
  BaseFormGroupSwitch                 as FormGroupUpstreamUseHttps,
  BaseFormGroupInput                  as FormGroupUpstreamDatabasePath,
  BaseFormGroupInputNumber            as FormGroupUpstreamSqliteDatabaseRetention,
  BaseFormGroupInput                  as FormGroupCollectorHost,
  BaseFormGroupInputNumber            as FormGroupCollectorPort,
  BaseFormGroupSwitch                 as FormGroupCollectorUseHttps,
  BaseFormGroupInput                  as FormGroupCollectorInactiveEndpointsExpiration,
  BaseFormGroupSwitch                 as FormGroupCollectorArpLookup,
  BaseFormGroupSwitch                 as FormGroupCollectorNetworkBehaviorAnalysis,
  BaseFormGroupInputNumber            as FormGroupCollectorQueryCacheTime,
  BaseFormGroupInputNumber            as FormGroupCollectorDatabasePersistenceInterval,
  BaseFormGroupInputNumber            as FormGroupCollectorClusterResyncInterval,
  BaseFormGroupTextarea               as FormGroupCollectorAdditionalEnv,
  BaseFormGroupSwitch                 as FormGroupQueryRecordUnmatched,
  BaseFormGroupSwitch                 as FormGroupProxyUseProxy,
  BaseFormGroupInput                  as FormGroupProxyHost,
  BaseFormGroupInputNumber            as FormGroupProxyPort,
  BaseFormGroupSwitch                 as FormGroupProxyVerifySsl,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
