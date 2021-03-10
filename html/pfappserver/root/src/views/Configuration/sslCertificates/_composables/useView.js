import { customRef, toRefs } from '@vue/composition-api'
import { useViewProps as useBaseViewProps } from '@/composables/useView'
import { certificates } from '../config'

const useViewProps = {
  ...useBaseViewProps,

  id: {
    type: String
  }
}

const useView = (props, context) => {

  const { root: { $router } = {} } = context

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

  return {
    tabIndex
  }
}

export {
  useViewProps,
  useView
}
