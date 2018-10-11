import { mysqlLimits as sqlLimits } from '@/globals/mysqlLimits'

export const pfDatabaseSchema = {
  node: {
    mac: {
      type: String,
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
      type: String,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    regdate: {
      type: String,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    unregdate: {
      type: String,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    lastskip: {
      type: String,
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
      type: String,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    last_dhcp: {
      type: String,
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
      type: String,
      enum: ['no', 'yes'],
      default: 'no'
    },
    autoreg: {
      type: String,
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
      type: String,
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
      type: String,
      format: 'YYYY-MM-DD HH:mm:ss',
      default: '0000-00-00 00:00:00'
    },
    expiration: {
      type: String,
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
      type: String,
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
      type: String,
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
      type: String,
      maxLength: 255,
      default: null
    },
    anniversary: {
      type: String,
      maxLength: 255,
      default: null
    },
    birthday: {
      type: String,
      maxLength: 255,
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
