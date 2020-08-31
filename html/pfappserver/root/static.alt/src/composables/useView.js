export const useViewProps = {
  id: {
    type: String
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  }
}

export const useView = () => {
  return {
    rootRef: null,

    form: {},
    meta: {},
    titleLabel: null,

    actionKey: false,
    isLoading: false,
    isDeletable: true,
    isValid: true,

    doCreate: () => {},
    doClone: () => {},
    doClose: () => {},
    doRemove: () => {},
    doReset: () => {},
    doSave: () => {}
  }
}
