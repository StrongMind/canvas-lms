import _ from 'underscore'
import OverridesActions from '../actions/OverridesActions'

const {
  SET_OVERRIDES,
} = OverridesActions;

const initialState = {
  overrides: [],
};

const handlers = {
  [SET_OVERRIDES]: (state, action) => {
    const newState = _.extend({}, state);
    newState.overrides = action.payload;

    return newState;
  }
};

function reducer (state, action) {
  const prevState = state || initialState;
  const handler = handlers[action.type];

  if (handler) return handler(prevState, action);

  return prevState;
};

export default reducer
