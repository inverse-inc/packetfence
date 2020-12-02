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
import BaseFormGroupStatus from './BaseFormGroupStatus'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupActions                as FormGroupActions,
  BaseFormGroupAnswers                as FormGroupAnswers,
  BaseFormGroupCondition              as FormGroupCondition,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupToggleNoYes            as FormGroupMergeAnswer,
  BaseFormGroupChosenOne              as FormGroupRadiusStatus,
  BaseFormGroupChosenOne              as FormGroupResponseCode,
  BaseFormGroupChosenOne              as FormGroupRole,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRunActions,
  BaseFormGroupChosenMultiple         as FormGroupScopes,
  BaseFormGroupStatus                 as FormGroupStatus,

  BaseViewCollectionItem              as BaseView,
  TheForm,
  TheView
}
