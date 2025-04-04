import {BaseViewCollectionItem} from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupSwitch,
  BaseFormGroupTextarea,
} from '@/components/new/'
import {BaseFormGroupIntervalUnit} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'
import ToggleStatus from './ToggleStatus'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInputNumber            as FormGroupBatch,
  BaseFormGroupTextarea               as FormGroupCertificates,
  BaseFormGroupIntervalUnit           as FormGroupDelay,
  BaseFormGroupIntervalUnit           as FormGroupDeleteWindow,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupSwitch                 as FormGroupFilterEvents,
  BaseFormGroupInput                  as FormGroupGroupId,
  BaseFormGroupSwitch                 as FormGroupHeuristics,
  BaseFormGroupInputNumber            as FormGroupHistoryBatch,
  BaseFormGroupIntervalUnit           as FormGroupHistoryTimeout,
  BaseFormGroupIntervalUnit           as FormGroupHistoryWindow,
  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupKafkaBrokers,
  BaseFormGroupInput                  as FormGroupKafkaPass,
  BaseFormGroupInput                  as FormGroupKafkaUser,
  BaseFormGroupChosenOne              as FormGroupSchedule,
  BaseFormGroupSwitch                 as FormGroupProcessSwitchranges,
  BaseFormGroupInput                  as FormGroupReadTopic,
  BaseFormGroupSwitch                 as FormGroupRotate,
  BaseFormGroupInputNumber            as FormGroupRotateBatch,
  BaseFormGroupIntervalUnit           as FormGroupRotateTimeout,
  BaseFormGroupIntervalUnit           as FormGroupRotateWindow,
  BaseFormGroupInput                  as FormGroupSendTopic,
  BaseFormGroupInputNumber            as FormGroupSessionBatch,
  BaseFormGroupIntervalUnit           as FormGroupSessionTimeout,
  BaseFormGroupIntervalUnit           as FormGroupSessionWindow,
  BaseFormGroupSwitch                 as FormGroupStatus,
  BaseFormGroupIntervalUnit           as FormGroupTimeout,
  BaseFormGroupIntervalUnit           as FormGroupUnregWindow,
  BaseFormGroupInput                  as FormGroupUuid,
  BaseFormGroupSwitch                 as FormGroupVoip,
  BaseFormGroupIntervalUnit           as FormGroupWindow,
  BaseFormGroupInput                  as FormGroupKafkaBrokers,
  BaseFormGroupInput                  as FormGroupKafkaPass,
  BaseFormGroupInput                  as FormGroupKafkaUser,
  BaseFormGroupInput                  as FormGroupReadTopic,
  BaseFormGroupInput                  as FormGroupSendTopic,
  BaseFormGroupInput                  as FormGroupUuid,
  BaseFormGroupInput                  as FormGroupGroupId,
  BaseFormGroupSwitch                 as FormGroupFilterEvents,
  BaseFormGroupSwitch                 as FormGroupHeuristics,

  TheForm,
  TheView,
  ToggleStatus
}
