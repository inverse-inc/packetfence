import i18n from '@/utils/locale'
import { mysqlLimits as sqlLimits } from '@/globals/mysqlLimits'
import {
  and,
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

export class pfDatabaseSchemaType {}
export class pfString extends pfDatabaseSchemaType {}
export class pfNumber extends pfDatabaseSchemaType {}
export class pfDatetime extends pfDatabaseSchemaType {}
export class pfEnum extends pfDatabaseSchemaType {}
export class pfEmail extends pfDatabaseSchemaType {}
export class pfMac extends pfDatabaseSchemaType {}

export const buildValidationFromTableSchemas = (...tableSchemas) => {
  let validation = {}
  for (var tableSchema of tableSchemas) {
    for (let [columnKey, columnSchema] of Object.entries(tableSchema)) {
      // eslint-disable-next-line
      if ('type' in columnSchema && new columnSchema.type() instanceof pfDatabaseSchemaType) {
        // pfDatabaseSchema definition:
        //   Create vuelidate struct from one or more tableSchema(s).
        //   Columns are not unique since more than one tableSchema can utilize the same key(s).
        //   We will overwrite each key (if more than one exists) instead of merging (overloading).
        validation[columnKey] = buildValidationFromColumnSchemas(columnSchema)
      } else {
        // Manual definition:
        //   Create vuelidate struct from one or more direct definitions.
        //   We will merge identical keys (if one already exists) instead of overwriting.
        if (!(columnKey in validation)) validation[columnKey] = {}
        Object.assign(validation[columnKey], columnSchema)
      }
    }
  }
  return validation
}

export const buildValidationFromColumnSchemas = (...columnSchemas) => {
  let validation = {}
  for (let columnSchema of columnSchemas) {
    // eslint-disable-next-line
    if ('type' in columnSchema && new columnSchema.type() instanceof pfDatabaseSchemaType) {
      switch (true) {
        case (columnSchema.type === pfString):
          Object.assign(validation, {
            [i18n.t('Maximum {maxLength} characters.', columnSchema)]: maxLength(columnSchema.maxLength)
          })
          break
        case (columnSchema.type === pfNumber):
          Object.assign(validation, {
            [i18n.t('Must be numeric.')]: numeric,
            [i18n.t('Minimum value of {min}.', columnSchema)]: minValue(columnSchema.min),
            [i18n.t('Maximum value of {max}.', columnSchema)]: maxValue(columnSchema.max)
          })
          break
        case (columnSchema.type === pfDatetime):
          if ('format' in columnSchema) {
            let allowZero = (columnSchema.default && columnSchema.default === columnSchema.format.replace(/[a-z]/gi, '0'))
            Object.assign(validation, {
              [i18n.t('Invalid date.')]: isDateFormat(columnSchema.format, allowZero)
            })
          }
          break
        case (columnSchema.type === pfEnum):
          if ('enum' in columnSchema) {
            Object.assign(validation, {
              [i18n.t('Invalid value.')]: inArray(columnSchema.enum)
            })
          }
          break
        case (columnSchema.type === pfEmail):
          Object.assign(validation, {
            [i18n.t('Invalid email address.')]: email,
            [i18n.t('Maximum {maxLength} characters.', columnSchema)]: maxLength(columnSchema.maxLength)
          })
          break
        case (columnSchema.type === pfMac):
          Object.assign(validation, {
            [i18n.t('Invalid MAC address.')]: and(minLength(17), maxLength(17), macAddress)
          })
          break
      }
    } else {
      Object.assign(validation, columnSchema)
    }
  }
  return validation
}

export const pfDatabaseSchema = {
  node: {
    mac: {
      type: pfMac,
      maxLength: 17
    },
    pid: {
      type: pfString,
      maxLength: 255,
      default: 'default'
    },
    category_id: Object.assign(
      sqlLimits.int,
      {
        type: pfNumber,
        default: null
      }
    ),
    detect_date: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    regdate: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    unregdate: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    lastskip: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    time_balance: Object.assign(
      sqlLimits.uint,
      {
        type: pfNumber,
        default: null
      }
    ),
    bandwidth_balance: Object.assign(
      sqlLimits.ubigint,
      {
        type: pfNumber,
        default: null
      }
    ),
    status: {
      type: pfString,
      maxLength: 15,
      default: 'unreg'
    },
    user_agent: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    computername: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    notes: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    last_arp: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    last_dhcp: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    dhcp_fingerprint: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    dhcp6_fingerprint: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    dhcp_vendor: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    dhcp6_enterprise: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    device_type: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    device_class: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    device_version: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    device_score: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    device_manufacturer: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    bypass_vlan: {
      type: pfString,
      maxLength: 50,
      default: null
    },
    voip: {
      type: pfEnum,
      enum: ['no', 'yes'],
      default: 'no'
    },
    autoreg: {
      type: pfEnum,
      enum: ['no', 'yes'],
      default: 'no'
    },
    sessionid: {
      type: pfString,
      maxLength: 30,
      default: null
    },
    machine_account: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    bypass_role_id: Object.assign(
      sqlLimits.int,
      {
        type: pfNumber,
        default: null
      }
    ),
    last_seen: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    }
  },
  password: {
    tenant_id: Object.assign(
      sqlLimits.int,
      {
        type: pfNumber,
        default: 1
      }
    ),
    pid: {
      type: pfString,
      maxLength: 255
    },
    password: {
      type: pfString,
      maxLength: 255
    },
    valid_from: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    expiration: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: ''
    },
    access_duration: {
      type: pfString,
      maxLength: 255
    },
    access_level: {
      type: pfString,
      maxLength: 255,
      default: 'NONE'
    },
    category: Object.assign(
      sqlLimits.int,
      {
        type: pfNumber,
        default: null
      }
    ),
    sponsor: Object.assign(
      sqlLimits.tinyint,
      {
        type: pfNumber,
        default: 0
      }
    ),
    unregdate: {
      type: pfDatetime,
      datetimeFormat: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    login_remaining: Object.assign(
      sqlLimits.int,
      {
        type: pfNumber,
        default: null
      }
    )
  },
  person: {
    tenant_id: Object.assign(
      sqlLimits.int,
      {
        type: pfNumber,
        default: 1
      }
    ),
    pid: {
      type: pfString,
      maxLength: 255
    },
    firstname: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    lastname: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    email: {
      type: pfEmail,
      maxLength: 255,
      default: null
    },
    telephone: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    company: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    address: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    notes: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    sponsor: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    anniversary: {
      type: pfString,
      maxLength: 255,
      format: 'YYYY-MM-DD',
      default: null
    },
    birthday: {
      type: pfString,
      maxLength: 255,
      format: 'YYYY-MM-DD',
      default: null
    },
    gender: {
      type: pfString,
      maxLength: 1,
      default: null
    },
    lang: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    nickname: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    cell_phone: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    work_phone: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    title: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    building_number: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    apartment_number: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    room_number: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    custom_field_1: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    custom_field_2: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    custom_field_3: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    custom_field_4: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    custom_field_5: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    custom_field_6: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    custom_field_7: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    custom_field_8: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    custom_field_9: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    portal: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    source: {
      type: pfString,
      maxLength: 255,
      default: null
    },
    psk: {
      type: pfString,
      maxLength: 255,
      default: null
    }
  }
}
