import {
  BaseFormButtonBar,
  BaseFormGroupChosenCountry,
  BaseFormGroupInput,
  BaseFormGroupSwitch,
} from '@/components/new/'
import BaseFormGroupCertificate from './BaseFormGroupCertificate'
import BaseFormGroupPrivateKey from './BaseFormGroupPrivateKey'
import BaseFormGroupLetsEncryptCommonName from './BaseFormGroupLetsEncryptCommonName'
import BaseFormGroupIntermediateCertificateAuthorities
  from './BaseFormGroupIntermediateCertificateAuthorities'
import TheCsr from './TheCsr'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                               as FormButtonBar,

  BaseFormGroupSwitch                             as FormGroupLetsEncrypt,
  BaseFormGroupLetsEncryptCommonName              as FormGroupLetsEncryptCommonName,
  BaseFormGroupCertificate                        as FormGroupCa,
  BaseFormGroupCertificate                        as FormGroupCertificate,
  BaseFormGroupPrivateKey                         as FormGroupPrivateKey,
  BaseFormGroupSwitch                             as FormGroupCheckChain,
  BaseFormGroupIntermediateCertificateAuthorities as FormGroupIntermediateCertificationAuthorities,
  BaseFormGroupChosenCountry                      as FormGroupCsrCountry,
  BaseFormGroupInput                              as FormGroupCsrState,
  BaseFormGroupInput                              as FormGroupCsrLocality,
  BaseFormGroupInput                              as FormGroupCsrOrganizationName,
  BaseFormGroupInput                              as FormGroupCsrCommonName,
  BaseFormGroupInput                              as FormGroupCsrSubjectAltNames,

  TheCsr,
  TheForm,
  TheView
}
