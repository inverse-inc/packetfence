import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupTextarea,
  BaseFormGroupToggle,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleNoYes
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit
} from '@/views/Configuration/_components/new/'
import BaseFormGroupRules from './BaseFormGroupRules'
import BaseFormGroupTest from './BaseFormGroupTest'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem                    as BaseView,
  BaseFormButtonBar                         as FormButtonBar,

  BaseFormGroupInput                        as FormGroupIdentifier,
  BaseFormGroupInput                        as FormGroupPath,
  BaseFormGroupIntervalUnit                 as FormGroupRateLimit,
  BaseFormGroupRules                        as FormGroupRules,
  BaseFormGroupToggleDisabledEnabled        as FormGroupStatus,
  BaseFormGroupTest                         as FormGroupTest,

  TheForm,
  TheView
}
