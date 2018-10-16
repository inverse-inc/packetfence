import i18n from '@/utils/locale'
import { mysqlLimits as sqlLimits } from '@/globals/mysqlLimits'
import {
  inArray,
  isDateFormat
} from '@/globals/pfValidators'
import {
  email,
  macAddress,
  maxLength,
  minLength,
  maxValue,
  minValue,
  numeric
} from 'vuelidate/lib/validators'

export class Datetime {}
export class Enum {}
export class Email {}
export class Mac {}

export const buildValidationFromTableSchemas = (...tableSchemas) => {
  let validation = {}
  for (let tableSchema of tableSchemas) {
    for (let [columnKey, columnSchema] of Object.entries(tableSchema)) {
      // if (!(columnKey in validation)) validation[columnKey] = {}
      if ('type' in columnSchema) {
        // direct definition
        validation[columnKey] = {} // do not overload, only overwrite
        switch (true) {
          case (columnSchema.type === String):
            Object.assign(validation[columnKey], {
              [i18n.t('Maximum {maxLength} characters.', columnSchema)]: maxLength(columnSchema.maxLength)
            })
            break
          case (columnSchema.type === Number):
            Object.assign(validation[columnKey], {
              [i18n.t('Must be numeric.')]: numeric,
              [i18n.t('Minimum value of {min}.', columnSchema)]: minValue(columnSchema.min),
              [i18n.t('Maximum value of {max}.', columnSchema)]: maxValue(columnSchema.max)
            })
            break
          case (columnSchema.type === Datetime):
            if (columnSchema.format) {
              let allowZero = (columnSchema.default && columnSchema.default === columnSchema.format.replace(/[a-z]/gi, '0'))
              Object.assign(validation[columnKey], {
                [i18n.t('Invalid date.')]: isDateFormat(columnSchema.format, allowZero)
              })
            }
            break
          case (columnSchema.type === Enum):
            if (columnSchema.enum) {
              Object.assign(validation[columnKey], {
                [i18n.t('Invalid value.')]: inArray(columnSchema.enum)
              })
            }
            break
          case (columnSchema.type === Email):
            Object.assign(validation[columnKey], {
              [i18n.t('Invalid email address.')]: email,
              [i18n.t('Maximum {maxLength} characters.', columnSchema)]: maxLength(columnSchema.maxLength)
            })
            break
          case (columnSchema.type === Mac):
            Object.assign(validation[columnKey], {
              [i18n.t('Invalid MAC address.')]: macAddress,
              [i18n.t('Maximum 17 characters.')]: maxLength(17),
              [i18n.t('Minimum 17 characters.')]: minLength(17)
            })
            break
        }
      } else {
        // direct definition
        if (!(columnKey in validation)) validation[columnKey] = {}
        Object.assign(validation[columnKey], columnSchema)
      }
    }
  }
  return validation
}

export const pfDatabaseSchema = {
  node: {
    mac: {
      type: Mac,
      maxLength: 17
    },
    pid: {
      type: String,
      maxLength: 255,
      default: 'default'
    },
    category_id: Object.assign(
      sqlLimits.int,
      {
        type: Number,
        default: null
      }
    ),
    detect_date: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    regdate: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    unregdate: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    lastskip: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    time_balance: Object.assign(
      sqlLimits.uint,
      {
        type: Number,
        default: null
      }
    ),
    bandwidth_balance: Object.assign(
      sqlLimits.ubigint,
      {
        type: Number,
        default: null
      }
    ),
    status: {
      type: String,
      maxLength: 15,
      default: 'unreg'
    },
    user_agent: {
      type: String,
      maxLength: 255,
      default: null
    },
    computername: {
      type: String,
      maxLength: 255,
      default: null
    },
    notes: {
      type: String,
      maxLength: 255,
      default: null
    },
    last_arp: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    last_dhcp: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    dhcp_fingerprint: {
      type: String,
      maxLength: 255,
      default: null
    },
    dhcp6_fingerprint: {
      type: String,
      maxLength: 255,
      default: null
    },
    dhcp_vendor: {
      type: String,
      maxLength: 255,
      default: null
    },
    dhcp6_enterprise: {
      type: String,
      maxLength: 255,
      default: null
    },
    device_type: {
      type: String,
      maxLength: 255,
      default: null
    },
    device_class: {
      type: String,
      maxLength: 255,
      default: null
    },
    device_version: {
      type: String,
      maxLength: 255,
      default: null
    },
    device_score: {
      type: String,
      maxLength: 255,
      default: null
    },
    device_manufacturer: {
      type: String,
      maxLength: 255,
      default: null
    },
    bypass_vlan: {
      type: String,
      maxLength: 50,
      default: null
    },
    voip: {
      type: Enum,
      enum: ['no', 'yes'],
      default: 'no'
    },
    autoreg: {
      type: Enum,
      enum: ['no', 'yes'],
      default: 'no'
    },
    sessionid: {
      type: String,
      maxLength: 30,
      default: null
    },
    machine_account: {
      type: String,
      maxLength: 255,
      default: null
    },
    bypass_role_id: Object.assign(
      sqlLimits.int,
      {
        type: Number,
        default: null
      }
    ),
    last_seen: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    }
  },
  password: {
    tenant_id: Object.assign(
      sqlLimits.int,
      {
        type: Number,
        default: 1
      }
    ),
    pid: {
      type: String,
      maxLength: 255
    },
    password: {
      type: String,
      maxLength: 255
    },
    valid_from: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    expiration: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: ''
    },
    access_duration: {
      type: String,
      maxLength: 255
    },
    access_level: {
      type: String,
      maxLength: 255,
      default: 'NONE'
    },
    category: Object.assign(
      sqlLimits.int,
      {
        type: Number,
        default: null
      }
    ),
    sponsor: Object.assign(
      sqlLimits.tinyint,
      {
        type: Number,
        default: 0
      }
    ),
    unregdate: {
      type: Datetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    login_remaining: Object.assign(
      sqlLimits.int,
      {
        type: Number,
        default: null
      }
    )
  },
  person: {
    tenant_id: sqlLimits.int,
    pid: {
      type: String,
      maxLength: 255
    },
    firstname: {
      type: String,
      maxLength: 255,
      default: null
    },
    lastname: {
      type: String,
      maxLength: 255,
      default: null
    },
    email: {
      type: Email,
      maxLength: 255,
      default: null
    },
    telephone: {
      type: String,
      maxLength: 255,
      default: null
    },
    company: {
      type: String,
      maxLength: 255,
      default: null
    },
    address: {
      type: String,
      maxLength: 255,
      default: null
    },
    notes: {
      type: String,
      maxLength: 255,
      default: null
    },
    sponsor: {
      type: Email,
      maxLength: 255,
      default: null
    },
    anniversary: {
      type: String,
      maxLength: 255,
      format: 'YYYY-MM-DD',
      default: null
    },
    birthday: {
      type: String,
      maxLength: 255,
      format: 'YYYY-MM-DD',
      default: null
    },
    gender: {
      type: String,
      maxLength: 1,
      default: null
    },
    lang: {
      type: String,
      maxLength: 255,
      default: null
    },
    nickname: {
      type: String,
      maxLength: 255,
      default: null
    },
    cell_phone: {
      type: String,
      maxLength: 255,
      default: null
    },
    work_phone: {
      type: String,
      maxLength: 255,
      default: null
    },
    title: {
      type: String,
      maxLength: 255,
      default: null
    },
    building_number: {
      type: String,
      maxLength: 255,
      default: null
    },
    apartment_number: {
      type: String,
      maxLength: 255,
      default: null
    },
    room_number: {
      type: String,
      maxLength: 255,
      default: null
    },
    custom_field_1: {
      type: String,
      maxLength: 255,
      default: null
    },
    custom_field_2: {
      type: String,
      maxLength: 255,
      default: null
    },
    custom_field_3: {
      type: String,
      maxLength: 255,
      default: null
    },
    custom_field_4: {
      type: String,
      maxLength: 255,
      default: null
    },
    custom_field_5: {
      type: String,
      maxLength: 255,
      default: null
    },
    custom_field_6: {
      type: String,
      maxLength: 255,
      default: null
    },
    custom_field_7: {
      type: String,
      maxLength: 255,
      default: null
    },
    custom_field_8: {
      type: String,
      maxLength: 255,
      default: null
    },
    custom_field_9: {
      type: String,
      maxLength: 255,
      default: null
    },
    portal: {
      type: String,
      maxLength: 255,
      default: null
    },
    source: {
      type: String,
      maxLength: 255,
      default: null
    },
    psk: {
      type: String,
      maxLength: 255,
      default: null
    }
  }
}
