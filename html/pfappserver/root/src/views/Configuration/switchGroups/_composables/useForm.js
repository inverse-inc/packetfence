import { computed, ref, toRefs } from '@vue/composition-api'
import { useFormMetaSchema } from '@/composables/useMeta'
import i18n from '@/utils/locale'
import { baseRoles } from '../../switches/config'
import schemaFn from '../schema'

export const useForm = (props, context) => {
  const {
    id,
    form,
    meta
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const roles = ref(baseRoles)
  $store.dispatch('$_roles/all').then(allRoles => {
    roles.value = [
      ...roles.value,
      ...allRoles.map(role => role.id)
    ]
  })

  const schema = computed(() => schemaFn(props, roles))
  const metaSchema = computed(() => useFormMetaSchema(meta, schema))

  const members = computed(() => form.value.members || [])

  const memberFields = [
    {
      key: 'id',
      label: i18n.t('Identifier'),
      required: true,
      sortable: true,
      visible: true
    },
    {
      key: 'description',
      label: i18n.t('Description'),
      sortable: true,
      visible: true
    },
    {
      key: 'type',
      label: i18n.t('Type'),
      sortable: true,
      visible: true
    },
    {
      key: 'buttons',
      label: '',
      locked: true,
      class: 'text-right'
    }
  ]
  const memberSortBy = ref('id')
  const memberSortDesc = ref(false)
  const memberIsLoading = ref(false)
  const memberIdentifier = ref(undefined)

  const refreshMembers = () => {
    $store.dispatch('$_switch_groups/getSwitchGroupMembers', id.value).then(members => {
      form.value.members = members
    })
  }

  const addMember = () => {
    $store.dispatch('$_switches/updateSwitch', { quiet: true, id: memberIdentifier.value, group: id.value }).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Switch <code>{id}</code> added to group.', { id: memberIdentifier.value }) })
      refreshMembers()
      memberIdentifier.value = undefined
    })
  }

  const removeMember = (item) => {
    $store.dispatch('$_switches/updateSwitch', { quiet: true, id: item.id, group: null }).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Switch <code>{id}</code> removed from group.', { id: item.id }) })
      refreshMembers()
    })
  }

  const switches = ref([])
  $store.dispatch('$_switches/all').then(s => switches.value = s)

  const filteredSwitches = computed(() => switches.value
    .filter(switche => !members.value.map(member => member.id).includes(switche.id))
    .map(switche => ({
      text: `${switche.id} (${switche.description})`,
      value: switche.id
    }))
  )

  const isAccessListMap = computed(() => {
    // inspect form value for `AccessListMap`
    const { AccessListMap } = form.value
    if (AccessListMap !== null)
      return AccessListMap === 'Y'

    // inspect meta placeholder for `AccessListMap`
    const { AccessListMap: { placeholder } = {} } =  meta.value
    return placeholder === 'Y'
  })

  const isRoleMap = computed(() => {
    // inspect form value for `RoleMap`
    const { RoleMap } = form.value
    if (RoleMap !== null)
      return RoleMap === 'Y'

    // inspect meta placeholder for `RoleMap`
    const { RoleMap: { placeholder } = {} } =  meta.value
    return placeholder === 'Y'
  })

  const isVpnMap = computed(() => {
    // inspect form value for `VpnMap`
    const { VpnMap } = form.value
    if (VpnMap !== null)
      return VpnMap === 'Y'

    // inspect meta placeholder for `VpnMap`
    const { VpnMap: { placeholder } = {} } =  meta.value
    return placeholder === 'Y'
  })

  const isUrlMap = computed(() => {
    // inspect form value for `UrlMap`
    const { UrlMap } = form.value
    if (UrlMap !== null)
      return UrlMap === 'Y'

    // inspect meta placeholder for `UrlMap`
    const { UrlMap: { placeholder } = {} } =  meta.value
    return placeholder === 'Y'
  })

  const isVlanMap = computed(() => {
    // inspect form value for `VlanMap`
    const { VlanMap } = form.value
    if (VlanMap !== null)
      return VlanMap === 'Y'

    // inspect meta placeholder for `VlanMap`
    const { VlanMap: { placeholder } = {} } =  meta.value
    return placeholder === 'Y'
  })

  return {
    schema: metaSchema,
    members,
    memberFields,
    memberSortBy,
    memberSortDesc,
    memberIsLoading,
    memberIdentifier,
    addMember,
    removeMember,

    switches,
    filteredSwitches,

    isAccessListMap,
    isRoleMap,
    isVpnMap,
    isUrlMap,
    isVlanMap,
    roles
  }
}
