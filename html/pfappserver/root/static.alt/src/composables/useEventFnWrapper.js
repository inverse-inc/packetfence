export default (fn, proxy) => (...args) => fn(proxy(...args))
