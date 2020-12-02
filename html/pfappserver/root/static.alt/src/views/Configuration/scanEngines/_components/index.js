import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit,
  BaseFormGroupToggleZeroOneAsOffOn
} from '@/views/Configuration/_components/new/'
import BaseFormGroupOses from './BaseFormGroupOses'
import BaseFormGroupWmiRules from './BaseFormGroupWmiRules'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupChosenMultiple         as FormGroupCategories,
  BaseFormGroupInput                  as FormGroupDomain,
  BaseFormGroupIntervalUnit           as FormGroupDuration,
  BaseFormGroupChosenOne              as FormGroupEngineIdentifier,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupIp,
  BaseFormGroupInput                  as FormGroupNessusClientpolicy,
  BaseFormGroupInput                  as FormGroupOpenvasAlertIdentifier,
  BaseFormGroupInput                  as FormGroupOpenvasConfigIdentifier,
  BaseFormGroupInput                  as FormGroupOpenvasReportFormatIdentifier,
  BaseFormGroupOses                   as FormGroupOses,
  BaseFormGroupInputPassword          as FormGroupPassword,
  BaseFormGroupToggleZeroOneAsOffOn   as FormGroupPreRegistration,
  BaseFormGroupInputNumber            as FormGroupPort,
  BaseFormGroupToggleZeroOneAsOffOn   as FormGroupPostRegistration,
  BaseFormGroupToggleZeroOneAsOffOn   as FormGroupRegistration,
  BaseFormGroupInput                  as FormGroupScannerName,
  BaseFormGroupChosenOne              as FormGroupSiteIdentifier,
  BaseFormGroupChosenOne              as FormGroupTemplateIdentifier,
  BaseFormGroupInput                  as FormGroupUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupVerifyHostname,
  BaseFormGroupWmiRules               as FormGroupWmiRules,

  TheForm,
  TheView
}
