import { configureStore } from '@reduxjs/toolkit';
import brandSlice from './brandSlice';
import alertSlice from './alertSlice';
import dashboardSlice from './dashboardSlice';

export const store = configureStore({
  reducer: {
    brand: brandSlice,
    alerts: alertSlice,
    dashboard: dashboardSlice,
  },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;