/**
 * createBatchLoader — request coalescer (DataLoader pattern).
 *
 * Collapses many single-key lookups that happen within a short time window into
 * a single batched call. This eliminates "N+1 request storms" — e.g. a table of
 * thousands of rows each resolving `GET node_category/<id>` collapses into one
 * (or a few) `POST node_categories/search` requests.
 *
 * Two layers of de-duplication:
 *   1. In-flight: a key already being loaded returns the same pending promise,
 *      so the same id requested by 500 rows hits the network once.
 *   2. Window: every key requested before the next flush is grouped into one
 *      batchFn() call.
 * An optional result cache additionally suppresses re-requests across renders
 * (including negative results, so an id the backend can't resolve isn't asked
 * for again).
 *
 * @param {(keys: Array<*>) => (Promise<Map<string,*>> | Promise<Array<*>>)} batchFn
 *   Resolves a batch of keys. Receives the de-duplicated list of original keys
 *   and must return either:
 *     - a Map keyed by `cacheKeyFn(key)` → value (preferred; robust to the
 *       backend omitting or reordering results), or
 *     - an Array of values positionally aligned to `keys`.
 *   Any key absent from the result resolves to `undefined`.
 * @param {Object} [options]
 * @param {number}  [options.wait=0]           ms to wait before flushing a batch.
 *                                             0 flushes at the end of the current
 *                                             macrotask, which already captures a
 *                                             full synchronous render pass; raise
 *                                             it to also coalesce across renders
 *                                             (e.g. virtual-scroll / pagination).
 * @param {number}  [options.maxBatchSize=100] max keys per batchFn() call; longer
 *                                             queues are split across calls.
 * @param {(key:*) => string} [options.cacheKeyFn] maps a key to a stable string.
 * @param {boolean|Map} [options.cache=false]  enable result caching (incl. misses).
 *                                             Pass a Map to share/inspect it.
 * @returns {{
 *   load: (key:*) => Promise<*>,
 *   prime: (key:*, value:*) => void,
 *   clear: (key:*) => void,
 *   clearAll: () => void
 * }}
 */
export const createBatchLoader = (batchFn, options = {}) => {
  const {
    wait = 0,
    maxBatchSize = 100,
    cacheKeyFn = key => `${key}`,
    cache = false
  } = options

  const resultCache = cache === true ? new Map() : (cache || null)
  const inflight = new Map() // cacheKey -> pending Promise
  let queue = []             // Array<{ key, ck, resolve, reject }>
  let timer = null

  const runChunk = (chunk) => {
    const keys = chunk.map(entry => entry.key)
    // defer the actual call so a throwing batchFn still rejects (never throws sync)
    Promise.resolve()
      .then(() => batchFn(keys))
      .then(result => {
        chunk.forEach((entry, index) => {
          let value
          if (result instanceof Map) value = result.get(entry.ck)
          else if (Array.isArray(result)) value = result[index]
          if (resultCache) resultCache.set(entry.ck, value)
          inflight.delete(entry.ck)
          entry.resolve(value)
        })
      })
      .catch(error => {
        // do not cache failures — let them retry on the next request
        chunk.forEach(entry => {
          inflight.delete(entry.ck)
          entry.reject(error)
        })
      })
  }

  const flush = () => {
    timer = null
    const batch = queue
    queue = []
    for (let i = 0; i < batch.length; i += maxBatchSize) {
      runChunk(batch.slice(i, i + maxBatchSize))
    }
  }

  const schedule = () => {
    if (timer === null) {
      timer = setTimeout(flush, wait)
    }
  }

  const load = (key) => {
    const ck = cacheKeyFn(key)
    if (resultCache && resultCache.has(ck)) {
      return Promise.resolve(resultCache.get(ck))
    }
    if (inflight.has(ck)) {
      return inflight.get(ck)
    }
    let resolve, reject
    const promise = new Promise((res, rej) => { resolve = res; reject = rej })
    inflight.set(ck, promise)
    queue.push({ key, ck, resolve, reject })
    schedule()
    return promise
  }

  const prime = (key, value) => {
    if (resultCache) {
      resultCache.set(cacheKeyFn(key), value)
    }
  }

  const clear = (key) => {
    const ck = cacheKeyFn(key)
    if (resultCache) resultCache.delete(ck)
    inflight.delete(ck)
  }

  const clearAll = () => {
    if (resultCache) resultCache.clear()
    inflight.clear()
  }

  return { load, prime, clear, clearAll }
}

export default createBatchLoader
