import { onMounted, onBeforeUnmount, ref } from '@vue/composition-api'

export default function useEvent(name, handler, el = ref(document)) {
  const remove = () => el.value && el.value.removeEventListener(name, handler)

  onMounted(() => el.value && el.value.addEventListener(name, handler))
  onBeforeUnmount(remove)

  return remove
}
