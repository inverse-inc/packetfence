import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleNoYes
} from '@/components/new/'
import BaseFormGroupActions from './BaseFormGroupActions'
import BaseFormGroupAnswers from './BaseFormGroupAnswers'
import BaseFormGroupCondition from './BaseFormGroupCondition'
import BaseFormGroupParams from './BaseFormGroupParams'
import BaseFormGroupStatus from './BaseFormGroupStatus'
import BaseFormGroupSwitch from './BaseFormGroupSwitch'
import TheForm from './TheForm'
import TheView from './TheView'
import ToggleStatus from './ToggleStatus'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupActions                as FormGroupActions,
  BaseFormGroupInput                  as FormGroupAnswer,
  BaseFormGroupAnswers                as FormGroupAnswers,
  BaseFormGroupCondition              as FormGroupCondition,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupLog,
  BaseFormGroupToggleNoYes            as FormGroupMergeAnswer,
  BaseFormGroupParams                 as FormGroupParams,
  BaseFormGroupChosenOne              as FormGroupRadiusStatus,
  BaseFormGroupChosenOne              as FormGroupResponseCode,
  BaseFormGroupChosenOne              as FormGroupRole,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRunActions,
  BaseFormGroupChosenMultiple         as FormGroupScopes,
  BaseFormGroupStatus                 as FormGroupStatus,
  BaseFormGroupSwitch                 as FormGroupSwitch,

  BaseViewCollectionItem              as BaseView,
  TheForm,
  TheView,
  ToggleStatus
}
