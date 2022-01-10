import { BaseViewResource } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit,
} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar         as FormButtonBar,

  BaseFormGroupInput        as FormGroupKeyBufferSize,
  BaseFormGroupInput        as FormGroupInnodbBufferPoolSize,
  BaseFormGroupInput        as FormGroupInnodbAdditionalMemPoolSize,
  BaseFormGroupInput        as FormGroupQueryCacheSize,
  BaseFormGroupInput        as FormGroupThreadConcurrency,
  BaseFormGroupInput        as FormGroupMaxConnections,
  BaseFormGroupInput        as FormGroupTableCache,
  BaseFormGroupInput        as FormGroupThreadCacheSize,
  BaseFormGroupInput        as FormGroupMaxAllowedPacket,
  BaseFormGroupChosenOne    as FormGroupPerformanceSchema,
  BaseFormGroupInput        as FormGroupMaxConnectErrors,
  BaseFormGroupChosenOne    as FormGroupMasterslave,
  BaseFormGroupInput        as FormGroupOtherMembers,
  BaseFormGroupIntervalUnit as FormGroupNetReadTimeout,
  BaseFormGroupIntervalUnit as FormGroupNetWriteTimeout,
  BaseViewResource          as BaseView,
  TheForm,
  TheView
}
