import { computed, ref, toRefs, unref } from '@vue/composition-api'
import { useFormMetaSchema } from '@/composables/useMeta'
import i18n from '@/utils/locale'
import { baseRoles } from '../config'
import schemaFn from '../schema'
import { useStore } from './useCollection'

const useFormProps = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  },
  id: {
    type: String
  }
}

const useForm = (props, context) => {

  const {
    form,
    meta
  } = toRefs(props)

  const { root: { $store } = {} } = context
  const {
    precreateItemAcls
  } = useStore($store)

  const roles = ref(baseRoles)
  $store.dispatch('$_roles/all').then(allRoles => {
    roles.value = [
      ...roles.value,
      ...allRoles.map(role => role.id)
    ]
  })

  const schema = computed(() => schemaFn(props, roles))
  const metaSchema = computed(() => useFormMetaSchema(meta, schema))
  const advancedMode = ref(false)

  const switchGroup = computed(() => {
    const { group } = unref(form)
    return group
  })

  const supported = computed(() => {
    const { type: { allowed = [], placeholder } = {} } = meta.value
    let { type } = form.value
    type = type || placeholder
    for (let i = 0; i < allowed.length; i++) {
      const { options = [] } = allowed[i]
      for (let j = 0; j < options.length; j++) {
        const { [j]: { value, supports = [] } = {} } = options
        if (value === type)
          return supports
      }
    }
    return  []
  })

  const supports = allowed => {
    if (advancedMode.value)
      return true
    for (let i = 0; i < allowed.length; i++) {
      if (supported.value.includes(allowed[i]))
        return true
    }
    return false
  }

  const isUplinkDynamic = computed(() => {
    // inspect form value for `uplink_dynamic`
    const { uplink_dynamic } = form.value
    if (uplink_dynamic !== null)
      return uplink_dynamic === 'dynamic'

    // inspect meta placeholder for `uplink_dynamic`
    const { uplink_dynamic: { placeholder } = {} } =  meta.value
    return placeholder === 'dynamic'
  })

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

  const isNetworkMap = computed(() => {
    // inspect form value for `NetworkMap`
    const { NetworkMap } = form.value
    if (NetworkMap !== null)
      return NetworkMap === 'Y'

    // inspect meta placeholder for `NetworkMap`
    const { NetworkMap: { placeholder } = {} } = meta.value
    return placeholder === 'Y'
  })

  const isInterfaceMap = computed(() => {
    // inspect form value for `InterfaceMap`
    const { InterfaceMap } = form.value
    if (InterfaceMap !== null)
      return InterfaceMap === 'Y'

    // inspect meta placeholder for `InterfaceMap`
    const { InterfaceMap: { placeholder } = {} } =  meta.value
    return placeholder === 'Y'
  })

  const isUsePushACLs = computed(() => {
    // inspect form value for `UsePushACLs`
    const { UsePushACLs } = form.value
    if (UsePushACLs !== null)
      return UsePushACLs === 'Y'

    // inspect meta placeholder for `UsePushACLs`
    const { UsePushACLs: { placeholder } = {} } =  meta.value
    return placeholder === 'Y'
  })

  const isUseDownloadableACLs = computed(() => {
    // inspect form value for `UseDownloadableACLs`
    const { UseDownloadableACLs } = form.value
    if (UseDownloadableACLs !== null)
      return UseDownloadableACLs === 'Y'

    // inspect meta placeholder for `UseDownloadableACLs`
    const { UseDownloadableACLs: { placeholder } = {} } =  meta.value
    return placeholder === 'Y'
  })

  const onPrecreate = () => {
    const { id } = form.value || {}
    precreateItemAcls({ id }).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Successfully precreated ACLs on switch <code>{id}</code>.', { id }) })
    }).catch(() => {
      $store.dispatch('notification/info', { message: i18n.t('Failed to precreate ACLs on switch <code>{id}</code>.', { id }) })
    })
  }

  return {
    advancedMode,
    schema: metaSchema,
    switchGroup,

    supports,
    isUplinkDynamic,
    isAccessListMap,
    isRoleMap,
    isVpnMap,
    isUrlMap,
    isVlanMap,
    isNetworkMap,
    isInterfaceMap,
    roles,

    isUsePushACLs,
    isUseDownloadableACLs,
    onPrecreate
  }
}

export {
  useFormProps,
  useForm
}
