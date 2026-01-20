import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { DashboardKPIs, TrendData } from '../types/api';

interface DashboardState {
  kpis: DashboardKPIs | null;
  trendData: TrendData[];
  yesterdayChanges: Array<{ brand: string; description: string }>;
  loading: boolean;
}

const initialState: DashboardState = {
  kpis: null,
  trendData: [],
  yesterdayChanges: [],
  loading: false,
};

const dashboardSlice = createSlice({
  name: 'dashboard',
  initialState,
  reducers: {
    setKPIs: (state, action: PayloadAction<DashboardKPIs>) => {
      state.kpis = action.payload;
    },
    setTrendData: (state, action: PayloadAction<TrendData[]>) => {
      state.trendData = action.payload;
    },
    setYesterdayChanges: (state, action: PayloadAction<Array<{ brand: string; description: string }>>) => {
      state.yesterdayChanges = action.payload;
    },
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.loading = action.payload;
    },
  },
});

export const { setKPIs, setTrendData, setYesterdayChanges, setLoading } = dashboardSlice.actions;
export default dashboardSlice.reducer;