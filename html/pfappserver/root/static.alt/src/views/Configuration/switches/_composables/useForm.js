import { computed, ref, toRefs, unref } from '@vue/composition-api'
import { useFormMetaSchema } from '@/composables/useMeta'
import schemaFn from '../schema'

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

  const schema = computed(() => schemaFn(props))
  const metaSchema = computed(() => useFormMetaSchema(meta, schema))
  const advancedMode = ref(false)

  const switchGroup = computed(() => {
    const { group } = unref(form)
    return group
  })

  const supported = computed(() => {
    const { type } = form.value
    const { type: { allowed = [] } = {} } = meta.value
    return allowed.reduce((_supports, group) => {
      const { options = [] } = group
      for (let i = 0; i < options.length; i++) {
        const { [i]: { value, supports = [] } = {} } = options
        if (value === type)
          _supports = supports
      }
      return _supports
    }, [])
  })

  const supports = (allowed) => {
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

  const roles = ref([
    'registration',
    'isolation',
    'macDetection',
    'inline'
  ])
  const { root: { $store } = {} } = context
  $store.dispatch('$_roles/all').then(allRoles => {
      roles.value = [
        ...roles.value,
        ...allRoles.map(role => role.id)
      ]
  })

  return {
    advancedMode,
    schema: metaSchema,
    switchGroup,

    supports,
    isUplinkDynamic,
    isAccessListMap,
    isRoleMap,
    isUrlMap,
    isVlanMap,
    roles
  }
}

export {
  useFormProps,
  useForm
}
