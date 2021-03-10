import {
  BaseButtonService,
  BaseFormButtonBar,

  BaseFormGroupChosenCountry,
  BaseFormGroupInput,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleFalseTrue
} from '@/components/new/'
import AlertServices from './AlertServices'
import BaseFormGroupCertificate from './BaseFormGroupCertificate'
import BaseFormGroupPrivateKey from './BaseFormGroupPrivateKey'
import BaseFormGroupLetsEncryptCommonName from './BaseFormGroupLetsEncryptCommonName'
import BaseFormGroupIntermediateCertificateAuthorities from './BaseFormGroupIntermediateCertificateAuthorities'
import TheCsr from './TheCsr'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseButtonService                               as ButtonService,
  BaseFormButtonBar                               as FormButtonBar,

  BaseFormGroupToggleFalseTrue                    as FormGroupLetsEncrypt,
  BaseFormGroupLetsEncryptCommonName              as FormGroupLetsEncryptCommonName,
  BaseFormGroupCertificate                        as FormGroupCertificate,
  BaseFormGroupPrivateKey                         as FormGroupPrivateKey,
  BaseFormGroupToggleDisabledEnabled              as FormGroupCheckChain,
  BaseFormGroupIntermediateCertificateAuthorities as FormGroupIntermediateCertificationAuthorities,
  BaseFormGroupChosenCountry                      as FormGroupCsrCountry,
  BaseFormGroupInput                              as FormGroupCsrState,
  BaseFormGroupInput                              as FormGroupCsrLocality,
  BaseFormGroupInput                              as FormGroupCsrOrganizationName,
  BaseFormGroupInput                              as FormGroupCsrCommonName,

  AlertServices,
  TheCsr,
  TheForm,
  TheView
}
