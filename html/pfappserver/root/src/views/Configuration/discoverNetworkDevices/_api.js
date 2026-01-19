import apiCall from '@/utils/api'

export default {
  discover: data => {
    // data: { addresses: string[], credentials: Credential[], options?: Options }
    return apiCall.post('discovernetworkdevice/discover', data).then(response => {
/*
      response.data = {
        "devices": [{
            "credential": {"type": "snmp_v2c", "snmp_read": "public"},
            "driver": "cisco_iosxe",
            "ip": "192.168.10.42",
            "vendor": "cisco",
            "os": "ios-xe",
            "version": "17.16.1",
            "system": "Cisco IOS-XE 17.16.1 Trademark. Inc Global Cisco",
            "oid": "1.3.6.1.4.1.9.1",
        }, {
            "credential": {"type": "snmp_v2c", "snmp_read": "public"},
            "driver": "cisco_iosxe",
            "ip": "192.168.10.101",
            "vendor": "cisco",
            "os": "ios-xe",
            "version": "17.15.1",
            "system": "Cisco IOS-XE 17.15.1 Trademark. Inc Global Cisco",
            "oid": "1.3.6.1.4.1.9.1",
        }],
        "snmp_result": [
            {"address": "192.168.10.79", "error": "Connection refused"},
            {"address": "192.168.10.111", "error": "Unknown OID"}
        ]
      }
*/
      return response.data
    })
  },
  pollTaskStatus: ({ task_id }) => {
    return apiCall.getQuiet(`pfqueue/task/${task_id}/status/poll`).then(response => {
      return response.data
    })
  }
}
