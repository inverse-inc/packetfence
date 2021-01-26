import { computed, ref, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useForm = (props, context) => {
  const {
    id,
    form
  } = toRefs(props)

  const { root: { $store } = {} } = context

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

  return {
    members,
    memberFields,
    memberSortBy,
    memberSortDesc,
    memberIsLoading,
    memberIdentifier,
    addMember,
    removeMember,

    switches,
    filteredSwitches
  }
}
