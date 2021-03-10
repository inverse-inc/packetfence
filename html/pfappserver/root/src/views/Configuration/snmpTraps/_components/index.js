import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit
} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupIntervalUnit           as FormGroupBounceDuration,
  BaseFormGroupToggleDisabledEnabled  as FormGroupTrapLimit,
  BaseFormGroupInput                  as FormGroupTrapLimitThreshold,
  BaseFormGroupChosenMultiple         as FormGroupTrapLimitAction,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
