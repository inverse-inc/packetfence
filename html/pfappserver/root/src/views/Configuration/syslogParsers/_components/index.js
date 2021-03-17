import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit
} from '@/views/Configuration/_components/new/'
import BaseFormGroupRules from './BaseFormGroupRules'
import BaseFormGroupTest from './BaseFormGroupTest'
import TheForm from './TheForm'
import TheView from './TheView'
import ToggleStatus from './ToggleStatus'

export {
  BaseViewCollectionItem                    as BaseView,
  BaseFormButtonBar                         as FormButtonBar,

  BaseFormGroupInput                        as FormGroupIdentifier,
  BaseFormGroupInput                        as FormGroupPath,
  BaseFormGroupIntervalUnit                 as FormGroupRateLimit,
  BaseFormGroupRules                        as FormGroupRules,
  BaseFormGroupToggleDisabledEnabled        as FormGroupStatus,
  BaseFormGroupChosenOne                    as FormGroupTenantIdentifier,
  BaseFormGroupTest                         as FormGroupTest,

  TheForm,
  TheView,
  ToggleStatus
}
