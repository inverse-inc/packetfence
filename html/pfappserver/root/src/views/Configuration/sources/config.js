import { pfActions } from '@/globals/pfActions'

export const decomposeSource = (item) => { // API -> form
  const { host = '' } = item
  return {
    ...item,
    host: host.split(',') // CSV to Array
  }
}

export const recomposeSource = (item) => { // form -> API
  const { host = [] } = item
  return {
    ...item,
    host: host.join(',') // Array to CSV
  }
}

export const administrationRuleActionsFromSourceType = (sourceType) => ([
  ...[
    pfActions.set_access_level,
    pfActions.set_tenant_id
  ],
  ...((['AD', 'LDAP', 'EDIR'].includes(sourceType))
    ? [
        pfActions.set_access_durations,
        pfActions.mark_as_sponsor
      ]
    : []
  )
])

export const authenticationRuleActionsFromSourceType = (sourceType) => ([
  ...[
    pfActions.set_role_by_name,
    pfActions.set_access_duration,
    pfActions.set_unreg_date,
    pfActions.set_time_balance,
    pfActions.set_bandwidth_balance,
    pfActions.set_role_from_source
  ],
  ...((['AD', 'LDAP'].includes(sourceType))
    ? [pfActions.set_role_on_not_found]
    : []
  )
])
