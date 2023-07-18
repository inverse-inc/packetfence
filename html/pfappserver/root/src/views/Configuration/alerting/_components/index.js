import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupTextarea,
  BaseFormGroupSwitch,
} from '@/components/new/'
import BaseFormGroupTestSmtp from './BaseFormGroupTestSmtp'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupTextarea               as FormGroupEmailAddr,
  BaseFormGroupInput                  as FormGroupFromAddr,
  BaseFormGroupChosenOne              as FormGroupSmtpEncryption,
  BaseFormGroupInputPassword          as FormGroupSmtpPassword,
  BaseFormGroupInputNumber            as FormGroupSmtpPort,
  BaseFormGroupInput                  as FormGroupSmtpServer,
  BaseFormGroupInputNumber            as FormGroupSmtpTimeout,
  BaseFormGroupInput                  as FormGroupSmtpUsername,
  BaseFormGroupSwitch                 as FormGroupSmtpVerifySsl,
  BaseFormGroupInput                  as FormGroupSubjectPrefix,
  BaseFormGroupTestSmtp               as FormGroupTestEmailAddr,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
