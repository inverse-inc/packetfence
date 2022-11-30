import { customRef, onMounted, toRefs } from '@vue/composition-api'
import { useViewProps as useBaseViewProps } from '@/composables/useView'
import { certificates } from '../config'

const useViewProps = {
  ...useBaseViewProps,

  id: {
    type: String
  }
}

const useView = (props, context) => {

  const { root: { $store, $router } = {} } = context

  const {
    id
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  const tabIndex = customRef((track, trigger) => ({
    get() {
      track()
      return certificates.indexOf(id.value)
    },
    set(newValue) {
      $router.push({ name: 'certificate', params: { id: certificates[newValue] } })
      trigger()
    }
  }))

  onMounted(() => {
    if ($store.getters['system/isSaas']) {
      tabIndex.value = 1 // focus RADIUS (HTTP is hidden)
    }
  })

  return {
    tabIndex
  }
}

export {
  useViewProps,
  useView
}
