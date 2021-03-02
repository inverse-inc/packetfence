import BaseArray from './BaseArray'
import BaseButtonConfirm from './BaseButtonConfirm'
import BaseButtonHelp from './BaseButtonHelp'
import BaseButtonRefresh from './BaseButtonRefresh'
import BaseButtonSave from './BaseButtonSave'
import BaseButtonService from './BaseButtonService'
import BaseButtonUpload from './BaseButtonUpload'
import BaseContainerLoading from './BaseContainerLoading'
import BaseForm from './BaseForm'
import BaseFormButtonBar from './BaseFormButtonBar'
import BaseFormGroup from './BaseFormGroup'
import BaseFormGroupArray, { props as BaseFormGroupArrayProps } from './BaseFormGroupArray'
import BaseFormGroupArrayDraggable, { props as BaseFormGroupArrayDraggableProps } from './BaseFormGroupArrayDraggable'
import BaseFormGroupChosenCountry from './BaseFormGroupChosenCountry'
import BaseFormGroupChosenMultiple, { props as BaseFormGroupChosenMultipleProps } from './BaseFormGroupChosenMultiple'
import BaseFormGroupChosenMultipleSearchable, { props as BaseFormGroupChosenMultipleSearchableProps } from './BaseFormGroupChosenMultipleSearchable'
import BaseFormGroupChosenOne, { props as BaseFormGroupChosenOneProps } from './BaseFormGroupChosenOne'
import BaseFormGroupChosenOneSearchable, { props as BaseFormGroupChosenOneSearchableProps } from './BaseFormGroupChosenOneSearchable'
import BaseFormGroupChosenTimezone from './BaseFormGroupChosenTimezone'
import BaseFormGroupInput from './BaseFormGroupInput'
import BaseFormGroupInputDate from './BaseFormGroupInputDate'
import BaseFormGroupInputDateTime from './BaseFormGroupInputDateTime'
import BaseFormGroupInputMultiplier from './BaseFormGroupInputMultiplier'
import BaseFormGroupInputNumber from './BaseFormGroupInputNumber'
import BaseFormGroupInputPassword from './BaseFormGroupInputPassword'
import BaseFormGroupInputPasswordGenerator from './BaseFormGroupInputPasswordGenerator'
import BaseFormGroupInputPasswordTest, { props as BaseFormGroupInputPasswordTestProps } from './BaseFormGroupInputPasswordTest'
import BaseFormGroupInputTest, { props as BaseFormGroupInputTestProps } from './BaseFormGroupInputTest'
import BaseFormGroupTextarea from './BaseFormGroupTextarea'
import BaseFormGroupTextareaTest, { props as BaseFormGroupTextareaTestProps } from './BaseFormGroupTextareaTest'
import BaseFormGroupTextareaUpload, { props as BaseFormGroupTextareaUploadProps } from './BaseFormGroupTextareaUpload'
import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from './BaseFormGroupToggle'
import BaseFormGroupToggleDisabledEnabled from './BaseFormGroupToggleDisabledEnabled'
import BaseFormGroupToggleFalseTrue from './BaseFormGroupToggleFalseTrue'
import BaseFormGroupToggleNoYes from './BaseFormGroupToggleNoYes'
import BaseFormGroupToggleNY from './BaseFormGroupToggleNY'
import BaseFormGroupToggleOffOn from './BaseFormGroupToggleOffOn'
import BaseFormTab from './BaseFormTab'
import BaseInput from './BaseInput'
import BaseInputArray, { props as BaseInputArrayProps } from './BaseInputArray'
import BaseInputChosenMultiple from './BaseInputChosenMultiple'
import BaseInputChosenOne, { props as BaseInputChosenOneProps } from './BaseInputChosenOne'
import BaseInputChosenOneSearchable, { props as BaseInputChosenOneSearchableProps } from './BaseInputChosenOneSearchable'
import BaseInputGroup from './BaseInputGroup'
import BaseInputGroupDate from './BaseInputGroupDate'
import BaseInputGroupDateTime from './BaseInputGroupDateTime'
import BaseInputGroupPassword from './BaseInputGroupPassword'
import BaseInputGroupPasswordGenerator from './BaseInputGroupPasswordGenerator'
import BaseInputGroupTextarea from './BaseInputGroupTextarea'
import BaseInputGroupTextareaUpload, { props as BaseInputGroupTextareaUploadProps } from './BaseInputGroupTextareaUpload'
import BaseInputGroupMultiplier from './BaseInputGroupMultiplier'
import BaseInputNumber from './BaseInputNumber'
import BaseInputPassword from './BaseInputPassword'
import BaseInputRange from './BaseInputRange'
import BaseInputRangePromise from './BaseInputRangePromise'
import BaseInputToggle, { props as BaseInputToggleProps } from './BaseInputToggle'
import BaseInputToggleAdvancedMode from './BaseInputToggleAdvancedMode'
import BaseTableEmpty from './BaseTableEmpty'
import BaseView from './BaseView'

import { mergeProps, renderHOCWithScopedSlots } from './utils'

export {
  // view
  BaseView,

  // form
  BaseForm,
  BaseFormButtonBar,
  BaseFormTab,

  // form group
  BaseFormGroup,
  BaseFormGroupArray, BaseFormGroupArrayProps,
  BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps,
  BaseFormGroupChosenCountry,
  BaseFormGroupChosenMultiple, BaseFormGroupChosenMultipleProps,
  BaseFormGroupChosenMultipleSearchable, BaseFormGroupChosenMultipleSearchableProps,
  BaseFormGroupChosenOne, BaseFormGroupChosenOneProps,
  BaseFormGroupChosenOneSearchable, BaseFormGroupChosenOneSearchableProps,
  BaseFormGroupChosenTimezone,
  BaseFormGroupInput,
  BaseFormGroupInputDate,
  BaseFormGroupInputDateTime,
  BaseFormGroupInputMultiplier,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator,
  BaseFormGroupInputPasswordTest, BaseFormGroupInputPasswordTestProps,
  BaseFormGroupInputTest, BaseFormGroupInputTestProps,
  BaseFormGroupTextarea,
  BaseFormGroupTextareaTest, BaseFormGroupTextareaTestProps,
  BaseFormGroupTextareaUpload, BaseFormGroupTextareaUploadProps,
  BaseFormGroupToggle, BaseFormGroupToggleProps,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleFalseTrue,
  BaseFormGroupToggleNoYes,
  BaseFormGroupToggleNY,
  BaseFormGroupToggleOffOn,

  // form inputs
  BaseInput,
  BaseInputArray, BaseInputArrayProps,
  BaseInputChosenMultiple,
  BaseInputChosenOne, BaseInputChosenOneProps,
  BaseInputChosenOneSearchable, BaseInputChosenOneSearchableProps,
  BaseInputGroup,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputGroupPasswordGenerator,
  BaseInputRange,
  BaseInputRangePromise,
  BaseInputToggle, BaseInputToggleProps,
  BaseInputToggleAdvancedMode,

  // bootstrap wrappers
  BaseInputGroupDate,
  BaseInputGroupDateTime,
  BaseInputGroupPassword,
  BaseInputGroupMultiplier,
  BaseInputGroupTextarea,
  BaseInputGroupTextareaUpload, BaseInputGroupTextareaUploadProps,

  // array wrapper
  BaseArray,

  // buttons
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseButtonRefresh,
  BaseButtonSave,
  BaseButtonService,
  BaseButtonUpload,

  // containers
  BaseContainerLoading,
  
  // tables
  BaseTableEmpty,

  // utils
  mergeProps,
  renderHOCWithScopedSlots
}
