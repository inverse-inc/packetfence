<template>
  <b-tab :title="$t('Permissions')">
    <b-card no-body class="mb-3">
      <b-card-header>
        <h4 class="d-inline mb-0">{{ $t('Admin Roles') }}</h4>
        <b-button :to="{ name: 'admin_roles' }" size="sm" variant="outline-primary" class="float-right">{{ $i18n.t('Manage') }}</b-button>
      </b-card-header>
      <b-card-body>
        <b-badge v-for="(role, index) in adminRoles" :key="index" class="mr-1" variant="secondary">{{ role }}</b-badge>
      </b-card-body>
    </b-card>
    <b-card no-body class="mb-3">
      <b-card-header>
        <h4 class="mb-0">{{ $t('Roles') }}</h4>
      </b-card-header>
      <b-card-body class="px-3 pt-3 pb-0">
        <b-row>
          <b-col cols="3" v-for="(acls, role) in aclContextAssociated" :key="role">
            <b-card class="mb-3" :title="roleToString(role)">
              <b-badge v-for="acl in acls" :key="`${role}_${acl}`"
                :title="`${role}_${acl}`" v-b-tooltip.hover.top.d300
                variant="secondary" class="mr-1">{{ acl }}</b-badge>
            </b-card>
          </b-col>
        </b-row>
      </b-card-body>
    </b-card>
  </b-tab>
</template>
<script>
import { computed } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const aclContext = computed(() => $store.getters['session/aclContext'])
  const aclContextAssociated = computed(() => aclContext.value
    .sort((a, b) => a.localeCompare(b))
    .reduce((associated, role) => {
      const [ suffix, ...prefixes ] = role.split('_').reverse()
      if (['CREATE', 'DELETE', 'READ', 'UPDATE', 'WRITE'].includes(suffix)) { // split by last '_'
        const prefix = prefixes.reverse().join('_')
        if (!(prefix in associated))
          associated[prefix] = []
        associated[prefix].push(suffix)
      }
      else { // split by first '_'
        const [ prefix, ...suffixes ] = role.split('_')
        const suffix = suffixes.join('_')
        if (!(prefix in associated))
          associated[prefix] = []
        associated[prefix].push(suffix)
      }
      return associated
    }, {})
  )

  const adminRoles = computed(() => $store.getters['session/adminRoles'])

  const roleToString = (role) => {
    return role
      .split('_')
      .map(role => `${role.charAt(0)}${role.slice(1).toLowerCase()}`)
      .join(' ')
  }

  return {
    aclContextAssociated,
    adminRoles,
    roleToString
  }
}

// @vue/component
export default {
  name: 'tab-permissions',
  inheritAttrs: false,
  setup
}
</script>