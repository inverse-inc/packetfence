import BaseFormGroupInputDateTime, { props as BaseFormGroupInputDateTimeProps } from './BaseFormGroupInputDateTime'
import { MysqlDatetimeMax, MysqlDatetimeMin } from '@/globals/mysql'

// For dates the backend checks with pf::util::validate_date (unregdate,
// allowed_unreg_date, valid_from, expiration): limit the picker to that range.
export const props = {
  ...BaseFormGroupInputDateTimeProps,

  // overload :min and :max defaults
  min: {
    type: [Date, String],
    default: MysqlDatetimeMin
  },
  max: {
    type: [Date, String],
    default: MysqlDatetimeMax
  }
}

export default {
  name: 'base-form-group-input-date-time-epoch',
  extends: BaseFormGroupInputDateTime,
  props
}
