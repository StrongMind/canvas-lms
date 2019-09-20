import { createStore, applyMiddleware } from 'redux'
import ReduxThunk from 'redux-thunk'
import overridesReducer from '../reducers/overridesReducer'

const createStoreWithMiddleware = applyMiddleware(
  ReduxThunk
)(createStore);

function configureStore (initialState) {
  return createStoreWithMiddleware(overridesReducer, initialState);
};

export default configureStore
