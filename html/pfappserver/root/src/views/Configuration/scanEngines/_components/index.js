import {BaseViewCollectionItem} from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupSwitch,
} from '@/components/new/'
import {BaseFormGroupIntervalUnit, BaseFormGroupOses} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem                    as BaseView,
  BaseFormButtonBar                         as FormButtonBar,

  BaseFormGroupChosenMultiple               as FormGroupCategories,
  BaseFormGroupIntervalUnit                 as FormGroupDuration,
  BaseFormGroupChosenOne                    as FormGroupEngineIdentifier,
  BaseFormGroupInput                        as FormGroupHost,
  BaseFormGroupInput                        as FormGroupIdentifier,
  BaseFormGroupInput                        as FormGroupIp,
  BaseFormGroupInput                        as FormGroupNessusClientpolicy,
  BaseFormGroupInput                        as FormGroupOpenvasAlertIdentifier,
  BaseFormGroupInput                        as FormGroupOpenvasConfigIdentifier,
  BaseFormGroupInput                        as FormGroupOpenvasReportFormatIdentifier,
  BaseFormGroupOses                         as FormGroupOses,
  BaseFormGroupInputPassword                as FormGroupPassword,
  BaseFormGroupSwitch                       as FormGroupPreRegistration,
  BaseFormGroupInputNumber                  as FormGroupPort,
  BaseFormGroupSwitch                       as FormGroupPostRegistration,
  BaseFormGroupSwitch                       as FormGroupRegistration,
  BaseFormGroupInput                        as FormGroupScannerName,
  BaseFormGroupChosenOne                    as FormGroupSiteIdentifier,
  BaseFormGroupChosenOne                    as FormGroupTemplateIdentifier,
  BaseFormGroupInput                        as FormGroupUsername,
  BaseFormGroupSwitch                       as FormGroupVerifyHostname,

  TheForm,
  TheView
}
