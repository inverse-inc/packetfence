import {
  BaseButtonService,
  BaseFormButtonBar,

  BaseFormGroupChosenCountry,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleFalseTrue
} from '@/components/new/'
import TheCsr from './TheCsr'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseButtonService                   as ButtonService,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupToggleFalseTrue        as FormGroupLetsEncrypt,
  BaseFormGroupTextarea               as FormGroupCertificate,
  BaseFormGroupTextarea               as FormGroupPrivateKey,
  BaseFormGroupToggleDisabledEnabled  as FormGroupCheckChain,

  BaseFormGroupChosenCountry          as FormGroupCsrCountry,
  BaseFormGroupInput                  as FormGroupCsrState,
  BaseFormGroupInput                  as FormGroupCsrLocality,
  BaseFormGroupInput                  as FormGroupCsrOrganizationName,
  BaseFormGroupInput                  as FormGroupCsrCommonName,

  TheCsr,
  TheForm,
  TheView
}

