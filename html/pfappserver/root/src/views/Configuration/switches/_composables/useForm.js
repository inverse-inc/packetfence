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
    meta,
    isLoading
  } = toRefs(props)

  const {
    id
  } = form.value || {}

  const { root: { $store } = {} } = context
  const {
    precreateItemAcls
  } = useStore($store)

  const schema = computed(() => schemaFn(props))
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

  const roles = ref(baseRoles)
  $store.dispatch('$_roles/all').then(allRoles => {
    roles.value = [
      ...roles.value,
      ...allRoles.map(role => role.id)
    ]
  })

  const ACLsTypeOptions = computed(() => {
    return [
      { text: i18n.t('Disabled'), value: undefined },
      ...((supports(['PushACLs']))
        ? [{ text: i18n.t('Push ACLs'), value: 'pushACLs' }] : []),
      ...((supports(['DownloadableListBasedEnforcement']))
        ? [{ text: i18n.t('Downloadable ACLs'), value: 'downloadableACLs' }] : []),
    ]
  })

  const ACLsPrecreate = computed(() => {
    const { ACLsType } = form.value || {}
    return isLoading.value === false && ACLsType === 'downloadableACLs'
  })

  const onPrecreate = () => {
    precreateItemAcls({ id }).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Successfully precreated ACLs for switch <code>{id}</code>.', { id }) })
    }).catch(() => {
      $store.dispatch('notification/info', { message: i18n.t('Failed to precreate ACLs for switch <code>{id}</code>.', { id }) })
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
    roles,

    ACLsTypeOptions,
    ACLsPrecreate,
    onPrecreate
  }
}

export {
  useFormProps,
  useForm
}
