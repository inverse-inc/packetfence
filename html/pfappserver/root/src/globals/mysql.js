export const MysqlLimits = {
  tinyint: {
    min: -128,
    max: 127
  },
  utinyint: {
    min: 0,
    max: 255
  },
  smallint: {
    min: -32768,
    max: 32767
  },
  usmallint: {
    min: 0,
    max: 65535
  },
  mediumint: {
    min: -8388608,
    max: 8388607
  },
  umediumint: {
    min: 0,
    max: 16777215
  },
  int: {
    min: -2147483648,
    max: 2147483647
  },
  uint: {
    min: 0,
    max: 4294967295
  },
  bigint: {
    min: -Math.pow(2, 63),
    max: Math.pow(2, 63) - 1
  },
  ubigint: {
    min: 0,
    max: Math.pow(2, 64) - 1
  }
}

class MysqlColumn {}
export class MysqlString extends MysqlColumn {}
export class MysqlNumber extends MysqlColumn {}
export class MysqlDatetime extends MysqlColumn {}
export class MysqlEnum extends MysqlColumn {}
export class MysqlEmail extends MysqlColumn {}
export class MysqlMac extends MysqlColumn {}

export const MysqlDatabase = {
  node: {
    mac: {
      type: MysqlMac,
      maxLength: 17
    },
    pid: {
      type: MysqlString,
      maxLength: 255,
      default: 'default'
    },
    category_id: Object.assign(
      MysqlLimits.int,
      {
        type: MysqlNumber,
        default: null
      }
    ),
    /* Do not validate backend variable, fixes #5509
    detect_date: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    */
    regdate: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    unregdate: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD',
      default: '0000-00-00'
    },
    lastskip: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    time_balance: Object.assign(
      MysqlLimits.uint,
      {
        type: MysqlNumber,
        default: null
      }
    ),
    bandwidth_balance: Object.assign(
      MysqlLimits.ubigint,
      {
        type: MysqlNumber,
        default: null
      }
    ),
    status: {
      type: MysqlString,
      maxLength: 15,
      default: 'unreg'
    },
    user_agent: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    computername: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    notes: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    last_arp: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    last_dhcp: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    dhcp_fingerprint: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    dhcp6_fingerprint: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    dhcp_vendor: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    dhcp6_enterprise: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    device_type: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    device_class: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    device_version: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    device_score: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    device_manufacturer: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    bypass_vlan: {
      type: MysqlString,
      maxLength: 50,
      default: null
    },
    voip: {
      type: MysqlEnum,
      enum: ['no', 'yes'],
      default: 'no'
    },
    autoreg: {
      type: MysqlEnum,
      enum: ['no', 'yes'],
      default: 'no'
    },
    sessionid: {
      type: MysqlString,
      maxLength: 30,
      default: null
    },
    machine_account: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    bypass_role_id: Object.assign(
      MysqlLimits.int,
      {
        type: MysqlNumber,
        default: null
      }
    ),
    last_seen: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    }
  },
  password: {
    tenant_id: Object.assign(
      MysqlLimits.int,
      {
        type: MysqlNumber,
        default: 1
      }
    ),
    pid: {
      type: MysqlString,
      maxLength: 255
    },
    password: {
      type: MysqlString,
      maxLength: 255
    },
    valid_from: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    expiration: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: ''
    },
    access_duration: {
      type: MysqlString,
      maxLength: 255
    },
    access_level: {
      type: MysqlString,
      maxLength: 255,
      default: 'NONE'
    },
    category: Object.assign(
      MysqlLimits.int,
      {
        type: MysqlNumber,
        default: null
      }
    ),
    sponsor: Object.assign(
      MysqlLimits.tinyint,
      {
        type: MysqlNumber,
        default: 0
      }
    ),
    unregdate: {
      type: MysqlDatetime,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    login_remaining: Object.assign(
      MysqlLimits.int,
      {
        type: MysqlNumber,
        default: null
      }
    )
  },
  person: {
    tenant_id: Object.assign(
      MysqlLimits.int,
      {
        type: MysqlNumber,
        default: 1
      }
    ),
    pid: {
      type: MysqlString,
      maxLength: 255
    },
    firstname: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    lastname: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    email: {
      type: MysqlEmail,
      maxLength: 255,
      default: null
    },
    telephone: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    company: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    address: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    notes: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    sponsor: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    anniversary: {
      type: MysqlString,
      maxLength: 255,
      format: 'YYYY-MM-DD',
      default: null
    },
    birthday: {
      type: MysqlString,
      maxLength: 255,
      format: 'YYYY-MM-DD',
      default: null
    },
    gender: {
      type: MysqlString,
      maxLength: 1,
      default: null
    },
    lang: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    nickname: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    cell_phone: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    work_phone: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    title: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    building_number: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    apartment_number: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    room_number: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    custom_field_1: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    custom_field_2: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    custom_field_3: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    custom_field_4: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    custom_field_5: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    custom_field_6: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    custom_field_7: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    custom_field_8: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    custom_field_9: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    portal: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    source: {
      type: MysqlString,
      maxLength: 255,
      default: null
    },
    psk: {
      type: MysqlString,
      maxLength: 255,
      default: null
    }
  }
}

import yup from '@/utils/yup'

export const validatorFromColumnSchemas = (...columnSchemas) => {
  let validator = yup.string().nullable()
  for (let columnSchema of columnSchemas) {
    validator = validator.concat( // extend
      yup.string().nullable().mysql(columnSchema)
    )
  }
  return validator
}
