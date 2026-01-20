import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { Alert, AlertFilters } from '../types/api';

interface AlertState {
  alerts: Alert[];
  filters: AlertFilters;
  loading: boolean;
  unreadCount: number;
}

const initialState: AlertState = {
  alerts: [],
  filters: {},
  loading: false,
  unreadCount: 0,
};

const alertSlice = createSlice({
  name: 'alerts',
  initialState,
  reducers: {
    setAlerts: (state, action: PayloadAction<Alert[]>) => {
      state.alerts = action.payload;
      state.unreadCount = action.payload.filter(alert => alert.severity === 'critical').length;
    },
    setFilters: (state, action: PayloadAction<AlertFilters>) => {
      state.filters = action.payload;
    },
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.loading = action.payload;
    },
    markAlertAsRead: (state, action: PayloadAction<string>) => {
      const alert = state.alerts.find(a => a.id === action.payload);
      if (alert && alert.severity === 'critical') {
        state.unreadCount = Math.max(0, state.unreadCount - 1);
      }
    },
  },
});

export const { setAlerts, setFilters, setLoading, markAlertAsRead } = alertSlice.actions;
export default alertSlice.reducer;