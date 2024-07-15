import {BaseViewResource} from '../../../_components/new/'
import {BaseFormButtonBar, BaseFormGroupInput, BaseFormGroupSwitch,} from '@/components/new/'
import {BaseFormGroupIntervalUnit} from '@/views/Configuration/_components/new/'
import BaseFormGroupStaticRoutes from './BaseFormGroupStaticRoutes'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                  as FormButtonBar,

  BaseFormGroupSwitch                as FormGroupDhcpdetector,
  BaseFormGroupIntervalUnit          as FormGroupDhcpRateLimiting,
  BaseFormGroupSwitch                as FormGroupRogueDhcpDetection,
  BaseFormGroupInput                 as FormGroupRogueinterval,
  BaseFormGroupSwitch                as FormGroupHostnameChangeDetection,
  BaseFormGroupSwitch                as FormGroupConnectionTypeChangeDetection,
  BaseFormGroupSwitch                as FormGroupDhcpoption82logger,
  BaseFormGroupSwitch                as FormGroupDhcpProcessIpv6,
  BaseFormGroupSwitch                as FormGroupForceListenerUpdateOnAck,
  BaseFormGroupSwitch                as FormGroupLearnNetworkCidrPerRole,
  BaseFormGroupInput                 as FormGroupInterfaceSnat,
  BaseFormGroupStaticRoutes          as FormGroupStaticroutes,

  BaseViewResource                   as BaseView,
  TheForm,
  TheView
}
