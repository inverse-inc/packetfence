import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenCountry,
  BaseFormGroupInput
} from '@/components/new/'
import {
  BaseFormGroupChosenOneProfile,
  BaseFormGroupRevokeReason
} from '../../_components/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem          as BaseView,
  BaseFormButtonBar               as FormButtonBar,

  BaseFormGroupInput              as FormGroupIdentifier,
  BaseFormGroupChosenOneProfile   as FormGroupProfileIdentifier,
  BaseFormGroupInput              as FormGroupCn,
  BaseFormGroupInput              as FormGroupMail,
  BaseFormGroupInput              as FormGroupDnsNames,
  BaseFormGroupInput              as FormGroupIpAddresses,
  BaseFormGroupInput              as FormGroupOrganisationalUnit,
  BaseFormGroupInput              as FormGroupOrganisation,
  BaseFormGroupChosenCountry      as FormGroupCountry,
  BaseFormGroupInput              as FormGroupState,
  BaseFormGroupInput              as FormGroupLocality,
  BaseFormGroupInput              as FormGroupStreetAddress,
  BaseFormGroupInput              as FormGroupPostalCode,
  BaseFormGroupInput              as FormGroupRevoked,
  BaseFormGroupRevokeReason       as FormGroupReason,

  TheForm,
  TheView
}
