import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea
} from '@/components/new/'
import {
  BaseFormGroupToggleZeroOneStringAsOffOn
} from '@/views/Configuration/_components/new/'
import {
  BaseFormGroupChosenOneCa,
  BaseFormGroupKeyType,
  BaseFormGroupKeySize,
  BaseFormGroupDigest,
  BaseFormGroupKeyUsage,
  BaseFormGroupExtendedKeyUsage,
} from '../../_components/'

import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem                  as BaseView,
  BaseFormButtonBar                       as FormButtonBar,

  BaseFormGroupInput                      as FormGroupIdentifier,
  BaseFormGroupChosenOneCa                as FormGroupCaId,
  BaseFormGroupInput                      as FormGroupName,
  BaseFormGroupInputNumber                as FormGroupValidity,
  BaseFormGroupKeyType                    as FormGroupKeyType,
  BaseFormGroupKeySize                    as FormGroupKeySize,
  BaseFormGroupDigest                     as FormGroupDigest,
  BaseFormGroupKeyUsage                   as FormGroupKeyUsage,
  BaseFormGroupExtendedKeyUsage           as FormGroupExtendedKeyUsage,
  BaseFormGroupToggleZeroOneStringAsOffOn as FormGroupP12MailPassword,
  BaseFormGroupInput                      as FormGroupP12MailSubject,
  BaseFormGroupInput                      as FormGroupP12MailFrom,
  BaseFormGroupTextarea                   as FormGroupP12MailHeader,
  BaseFormGroupTextarea                   as FormGroupP12MailFooter,
  BaseFormGroupToggleZeroOneStringAsOffOn as FormGroupSCEPEnabled,
  BaseFormGroupTextarea                   as FormGroupSCEPChallengePassword,
  BaseFormGroupTextarea                   as FormGroupSCEPAllowRenewal,

  TheForm,
  TheView
}
