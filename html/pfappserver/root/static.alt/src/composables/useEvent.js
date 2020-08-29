import { onMounted, onBeforeUnmount, ref } from '@vue/composition-api'

export default function useEvent(name, handler, el = ref(document)) {
  const removeEvent = () => el.value && el.value.removeEventListener(name, handler)

  onMounted(() => el.value && el.value.addEventListener(name, handler))
  onBeforeUnmount(removeEvent)

  return removeEvent
}
