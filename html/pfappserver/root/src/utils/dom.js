export const insertScript = (src, crossOrigin = undefined) => {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.async = true
    script.defer = true
    script.src = src
    script.onload = resolve
    script.onerror = reject

    if (crossOrigin && ['anonymous', 'use-credentials'].includes(crossOrigin)) {
      script.crossOrigin = crossOrigin
    }

    const head = document.head || document.getElementsByTagName('head')[0]
    head.appendChild(script)
  })
}