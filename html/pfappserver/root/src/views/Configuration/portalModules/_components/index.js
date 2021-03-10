import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggle,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import BaseFormGroupActions from './BaseFormGroupActions'
import BaseFormGroupModules from './BaseFormGroupModules'
import BaseFormGroupMultiSourceIdentifiers from './BaseFormGroupMultiSourceIdentifiers'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem                    as BaseView,
  BaseFormButtonBar                         as FormButtonBar,

  BaseFormGroupInput                        as FormGroupIdentifier,
  BaseFormGroupActions                      as FormGroupActions,
  BaseFormGroupChosenMultiple               as FormGroupAdminRole,
  BaseFormGroupInput                        as FormGroupAupTemplate,
  BaseFormGroupChosenMultiple               as FormGroupCustomFields,
  BaseFormGroupInput                        as FormGroupDescription,
  BaseFormGroupChosenMultiple               as FormGroupFieldsToSave,
  BaseFormGroupInput                        as FormGroupForcedSponsor,
  BaseFormGroupInput                        as FormGroupLandingTemplate,
  BaseFormGroupChosenMultiple               as FormGroupListRole,
  BaseFormGroupTextarea                     as FormGroupMessage,
  BaseFormGroupModules                      as FormGroupModules,
  BaseFormGroupMultiSourceIdentifiers       as FormGroupMultiSourceIdentifiers,
  BaseFormGroupTextarea                     as FormGroupMultiSourceAuthClasses,
  BaseFormGroupTextarea                     as FormGroupMultiSourceObjectClasses,
  BaseFormGroupTextarea                     as FormGroupMultiSourceTypes,
  BaseFormGroupChosenOne                    as FormGroupPidField,
  BaseFormGroupToggleDisabledEnabled        as FormGroupShowFirstModuleOnDefault,
  BaseFormGroupInput                        as FormGroupSignupTemplate,
  BaseFormGroupToggle                       as FormGroupSkipable,
  BaseFormGroupChosenOne                    as FormGroupSourceIdentifier,
  BaseFormGroupInput                        as FormGroupSslMobileconfigPath,
  BaseFormGroupInput                        as FormGroupSslPath,
  BaseFormGroupChosenMultiple               as FormGroupStoneRoles,
  BaseFormGroupChosenOne                    as FormGroupSurveyIdentifier,
  BaseFormGroupInput                        as FormGroupTemplate,
  BaseFormGroupInput                        as FormGroupUrl,
  BaseFormGroupInput                        as FormGroupUsername,
  BaseFormGroupToggle                       as FormGroupWithAup,

  TheForm,
  TheView
}
