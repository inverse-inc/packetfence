import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenCountry,
  BaseFormGroupChosenOne,
  BaseFormGroupFileUpload,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupSwitch,
} from '@/components/new/'
import {
  BaseFormGroupChosenOneProfile
} from '../../pki/_components/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem        as BaseView,
  BaseFormButtonBar             as FormButtonBar,

  BaseFormGroupFileUpload       as FormGroupCaCertPath,
  BaseFormGroupFileUpload       as FormGroupClientCertPath,
  BaseFormGroupFileUpload       as FormGroupClientKeyPath,
  BaseFormGroupChosenOne        as FormGroupCommonNameAttribute,
  BaseFormGroupInput            as FormGroupCommonNameFormat,
  BaseFormGroupChosenCountry    as FormGroupCountry,
  BaseFormGroupInput            as FormGroupIdentifier,
  BaseFormGroupInput            as FormGroupLocality,
  BaseFormGroupInput            as FormGroupOrganization,
  BaseFormGroupInput            as FormGroupOrganizationalUnit,
  BaseFormGroupInputPassword    as FormGroupPassword,
  BaseFormGroupInput            as FormGroupPostalCode,
  BaseFormGroupChosenOneProfile as FormGroupProfile,
  BaseFormGroupSwitch           as FormGroupRevokeOnRegistration,
  BaseFormGroupFileUpload       as FormGroupServerCertPath,
  BaseFormGroupInput            as FormGroupState,
  BaseFormGroupInput            as FormGroupStreetAddress,
  BaseFormGroupInput            as FormGroupUrl,
  BaseFormGroupInput            as FormGroupUsername,

  TheForm,
  TheView
}
