const OverrideActions = {
  SET_OVERRIDES: 'SET_OVERRIDES',

  setOverrides(value) {
    return {
      type: this.SET_OVERRIDES,
      payload: value,
    }
  }
}

export default OverrideActions
