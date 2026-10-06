import BaseInputGroupDateTime, { props as BaseInputGroupDateTimeProps } from './BaseInputGroupDateTime'
import { MysqlDatetimeMax, MysqlDatetimeMin } from '@/globals/mysql'

// For dates the backend checks with pf::util::validate_date (unregdate,
// allowed_unreg_date, valid_from, expiration): limit the picker to that range.
export const props = {
  ...BaseInputGroupDateTimeProps,

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
  name: 'base-input-group-date-time-epoch',
  extends: BaseInputGroupDateTime,
  props
}
