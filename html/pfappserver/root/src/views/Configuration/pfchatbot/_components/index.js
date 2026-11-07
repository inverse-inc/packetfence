import {BaseViewResource} from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupToggleDisabledEnabled,
} from '@/components/new/'
import BaseFormGroupApiKeyTest from './BaseFormGroupApiKeyTest'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar as FormButtonBar,

  BaseFormGroupChosenOne as FormGroupProvider,
  BaseFormGroupApiKeyTest as FormGroupApiKey,
  BaseFormGroupInput as FormGroupModel,
  BaseFormGroupInput as FormGroupPfUsername,
  BaseFormGroupInputPassword as FormGroupPfPassword,
  BaseFormGroupToggleDisabledEnabled as FormGroupPfVerifyTls,
  BaseFormGroupInputNumber as FormGroupLlmTimeout,
  BaseFormGroupInputNumber as FormGroupLlmRetries,
  BaseFormGroupInput as FormGroupRagEmbedModel,
  BaseFormGroupInput as FormGroupRagRerankModel,
  BaseFormGroupInputNumber as FormGroupFileMax,
  BaseFormGroupInputNumber as FormGroupFileThreadQuota,
  BaseFormGroupInputNumber as FormGroupFileUserQuota,
  BaseFormGroupInputNumber as FormGroupUploadTtlDays,

  BaseViewResource as BaseView,
  TheForm,
  TheView
}
