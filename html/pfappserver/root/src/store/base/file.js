const types = {
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error'
}

export default class FileStore {
  constructor (blob, encoding) {
    this.blob = blob
    this.encoding = encoding
  }

  module () {
    const state = () => {
      return {
        /**
         * private state(s)
        **/
        blob: this.blob || null, // File
        status: null,
        offsets: [0], // private map of line # => byte offset
        chunkSize: 1024 * 1024, // FileReader.slice chunk size (bytes)
        newLine: [10], // \n

        /**
         * public state(s)
        **/
        file: {
          name: this.blob.name || null, // from File|Blob
          lastModified: this.blob.lastModified || null, // from File|Blob
          lastModifiedDate: this.blob.lastModifiedDate || null, // from File|Blobs
          size: this.blob.size || null, // from File|Blob
          type: this.blob.type || null, // from File|Blob
          encoding: this.encoding || 'utf-8', // user defined character encoding
          percent: 0, // FileReader onprogress percent
          result: null, // FileReader onload result
          error: null // FileReader onerror error
        }
      }
    }

    const getters = {
      file: state => state.file,
      isError: state => state.status === types.ERROR,
      isLoading: state => state.status === types.LOADING
    }

    const actions = {
      setEncoding: ({ commit }, encoding) => {
        commit('SET_ENCODING', encoding)
        commit('RESET_OFFSETS')
      },
      setChunkSize: ({ commit }, size) => {
        commit('SET_CHUNK_SIZE', size)
      },
      setNewLine: ({ commit }, newLine) => {
        commit('SET_NEW_LINE', newLine)
        commit('RESET_OFFSETS')
      },
      readAsText: ({ commit }) => {
        commit('SET_READ_AS_TEXT', commit)
      },
      readLine: ({ state, dispatch }, lineIndex) => {
        return new Promise((resolve, reject) => {
          dispatch('buildOffset', lineIndex).then(() => {
            if (state.offsets.length > lineIndex + 1) {
              const start = state.offsets[lineIndex]
              const end = state.offsets[lineIndex + 1] - state.newLine.length
              dispatch('readSlice', { start, end }).then(result => {
                const decoded = new TextDecoder(state.file.encoding).decode(result)
                resolve(decoded)
              }).catch(err => {
                reject(err)
              })
            } else {
              resolve(undefined)
            }
          })
        })
      },
      readSlice: ({ commit, state }, { start, end }) => {
        return new Promise((resolve, reject) => {
          const reader = new FileReader()
          reader.onerror = (event) => {
            const { target: { error } = {} } = event
            commit('SET_ERROR', error)
            reader.abort()
            reject(error)
          }
          reader.onload = (event) => {
            const { target: { result } = {} } = event
            resolve(new Uint8Array(result))
          }
          start = Math.min(start, state.file.size)
          end = Math.min(end, state.file.size)
          const slice = state.blob.slice(start, end, state.file.type)
          reader.readAsArrayBuffer(slice)
        })
      },
      buildOffset: ({ commit, state, dispatch }, lineIndex) => {
        return new Promise((resolve, reject) => {
          const scan = async (index, start) => {
            const end = start + state.chunkSize
            let match = 0
            if (index <= lineNumber && state.offsets[index - 1] !== null) {
              await dispatch('readSlice', { start, end }).then(result => {
                let offset
                for (let c = 0; c <= result.length; c++) {
                  offset = start + c
                  if (offset === state.file.size) { // EOF
                    commit('SET_OFFSET', { index, offset: null })
                    resolve()
                    return
                  } else if (result[c] === state.newLine[match]) {
                    match++
                    if (match === state.newLine.length) { // EOL
                      match = 0
                      commit('SET_OFFSET', { index: index++, offset: offset + 1 })
                      if (index > lineNumber) break
                    }
                  } else {
                    match = 0
                  }
                }
                start += state.chunkSize
                scan(index, start) // recurse
              }).catch(error => {
                reject(error)
              })
            } else {
              resolve()
            }
          }
          const lineNumber = lineIndex + 1
          let index = state.offsets.length
          if (index <= lineNumber && state.offsets[index - 1] !== null) {
            let start = state.offsets[index - 1] // start at last known offset
            scan(index, start)
          } else {
            resolve()
          }
        })
      }
    }

    const mutations = {
      READER_PROGRESS: (state, event) => {
        state.status = types.LOADING
        const { lengthComputable, loaded, total } = event
        let percent = 0
        if (lengthComputable) {
          percent = Math.round((loaded / total) * 100)
        }
        state.file.percent = percent
      },
      READER_LOAD: (state, event) => {
        state.status = types.SUCCESS
        const { target: { result } = {} } = event
        state.file.result = result
      },
      READER_ERROR: (state, event) => {
        state.status = types.ERROR
        const { target: { error: { code, message, name } = {} } = {} } = event
        state.file.error = { code, message, name }
      },

      SET_PERCENT: (state, percent) => {
        state.percent = percent
      },
      SET_READ_AS_TEXT: (state, commit) => {
        const reader = new FileReader()
        reader.onprogress = (event) => {
          commit('READER_PROGRESS', event)
        }
        reader.onload = (event) => {
          commit('READER_LOAD', event)
        }
        reader.onerror = (event) => {
          commit('READER_ERROR', event)
        }
        reader.readAsText(state.blob, state.file.encoding)
      },
      SET_ENCODING: (state, encoding) => {
        state.encoding = encoding
      },
      SET_CHUNK_SIZE: (state, chunkSize) => {
        state.chunkSize = chunkSize
      },
      SET_NEW_LINE: (state, newLine) => {
        state.newLine = newLine.split('').map(c => c.charCodeAt(0))
      },
      SET_ERROR: (state, error) => {
        state.status = types.ERROR
        const { code, message, name } = error
        state.file.error = { code, message, name }
      },
      RESET_OFFSETS: (state) => {
        state.offsets = [0]
      },
      SET_OFFSET: (state, { index, offset }) => {
        state.offsets[index] = offset
      }
    }

    return {
      namespaced: true,
      state,
      getters,
      actions,
      mutations
    }
  }
}
