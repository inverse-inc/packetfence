import BaseArray from './BaseArray'
import BaseButtonConfirm from './BaseButtonConfirm'
import BaseButtonExportCsv from './BaseButtonExportCsv'
import BaseButtonHelp from './BaseButtonHelp'
import BaseButtonRefresh from './BaseButtonRefresh'
import BaseButtonSave from './BaseButtonSave'
import BaseButtonSaveSearch from './BaseButtonSaveSearch'
import BaseButtonService from './BaseButtonService'
import BaseButtonServiceSaas from './BaseButtonServiceSaas'
import BaseButtonServiceSystem from './BaseButtonServiceSystem'
import BaseButtonSystemdUpdate from './BaseButtonSystemdUpdate'
import BaseButtonUpload from './BaseButtonUpload'
import BaseContainerLoading from './BaseContainerLoading'
import BaseCsvImport from './BaseCsvImport'
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
import BaseFormGroupFileUpload, { props as BaseFormGroupFileUploadProps } from './BaseFormGroupFileUpload'
import BaseFormGroupInput, { props as BaseFormGroupInputProps } from './BaseFormGroupInput'
import BaseFormGroupInputDate from './BaseFormGroupInputDate'
import BaseFormGroupInputDateTime from './BaseFormGroupInputDateTime'
import BaseFormGroupInputMultiplier from './BaseFormGroupInputMultiplier'
import BaseFormGroupInputNumber from './BaseFormGroupInputNumber'
import BaseFormGroupInputPassword from './BaseFormGroupInputPassword'
import BaseFormGroupInputPasswordGenerator from './BaseFormGroupInputPasswordGenerator'
import BaseFormGroupInputPasswordTest, { props as BaseFormGroupInputPasswordTestProps } from './BaseFormGroupInputPasswordTest'
import BaseFormGroupInputTest, { props as BaseFormGroupInputTestProps } from './BaseFormGroupInputTest'
import BaseFormGroupSwitch from './BaseFormGroupSwitch';
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
import BaseIconPreference from './BaseIconPreference'
import BaseInput, { props as BaseInputProps } from './BaseInput'
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
import BaseInputToggle, { props as BaseInputToggleProps } from './BaseInputToggle'
import BaseInputToggleAdvancedMode from './BaseInputToggleAdvancedMode'
import BaseInputToggleFalseTrue from './BaseInputToggleFalseTrue'
import BaseLabel from './BaseLabel';
import BaseSearch from './BaseSearch'
import BaseSearchInputBasic from './BaseSearchInputBasic'
import BaseSearchInputAdvanced from './BaseSearchInputAdvanced'
import BaseSearchInputColumns from './BaseSearchInputColumns'
import BaseSearchInputLimit from './BaseSearchInputLimit'
import BaseSearchInputPage from './BaseSearchInputPage'
import BaseService from './BaseService'
import BaseServices from './BaseServices'
import BaseServiceSaas from './BaseServiceSaas'
import BaseServiceSystem from './BaseServiceSystem'
import BaseSystemdUpdate from './BaseSystemdUpdate'
import BaseTableEmpty from './BaseTableEmpty'
import BaseTableSortable from './BaseTableSortable'
import BaseUpload from './BaseUpload'
import BaseView from './BaseView'
import OnChangeFormGroupSwitch from './OnChangeFormGroupSwitch';

import { mergeProps, renderHOCWithScopedSlots } from './utils'

export {
  // views
  BaseCsvImport,
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
  BaseFormGroupFileUpload, BaseFormGroupFileUploadProps,
  BaseFormGroupInput, BaseFormGroupInputProps,
  BaseFormGroupInputDate,
  BaseFormGroupInputDateTime,
  BaseFormGroupInputMultiplier,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator,
  BaseFormGroupInputPasswordTest, BaseFormGroupInputPasswordTestProps,
  BaseFormGroupInputTest, BaseFormGroupInputTestProps,
  BaseFormGroupSwitch,
  BaseFormGroupTextarea,
  BaseFormGroupTextareaTest, BaseFormGroupTextareaTestProps,
  BaseFormGroupTextareaUpload, BaseFormGroupTextareaUploadProps,
  BaseFormGroupToggle, BaseFormGroupToggleProps,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleFalseTrue,
  BaseFormGroupToggleNoYes,
  BaseFormGroupToggleNY,
  BaseFormGroupToggleOffOn,
  OnChangeFormGroupSwitch,

  // icons
  BaseIconPreference,

  // form inputs
  BaseInput, BaseInputProps,
  BaseInputArray, BaseInputArrayProps,
  BaseInputChosenMultiple,
  BaseInputChosenOne, BaseInputChosenOneProps,
  BaseInputChosenOneSearchable, BaseInputChosenOneSearchableProps,
  BaseInputGroup,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputRange,
  BaseInputToggle, BaseInputToggleProps,
  BaseInputToggleAdvancedMode,
  BaseInputToggleFalseTrue,
  BaseLabel,

  // bootstrap wrappers
  BaseInputGroupDate,
  BaseInputGroupDateTime,
  BaseInputGroupPassword,
  BaseInputGroupPasswordGenerator,
  BaseInputGroupMultiplier,
  BaseInputGroupTextarea,
  BaseInputGroupTextareaUpload, BaseInputGroupTextareaUploadProps,

  // array wrapper
  BaseArray,

  // buttons
  BaseButtonConfirm,
  BaseButtonExportCsv,
  BaseButtonHelp,
  BaseButtonRefresh,
  BaseButtonSave,
  BaseButtonSaveSearch,
  BaseButtonService,
  BaseButtonServiceSaas,
  BaseButtonServiceSystem,
  BaseButtonSystemdUpdate,
  BaseButtonUpload,

  // containers
  BaseContainerLoading,

  // search
  BaseSearch,
  BaseSearchInputBasic,
  BaseSearchInputAdvanced,
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,

  // services
  BaseService,
  BaseServices,
  BaseServiceSaas,
  BaseServiceSystem,
  BaseSystemdUpdate,

  // tables
  BaseTableEmpty,
  BaseTableSortable,

  // file upload
  BaseUpload,

  // utils
  mergeProps,
  renderHOCWithScopedSlots
}
