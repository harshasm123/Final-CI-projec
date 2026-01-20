import { useQuery } from '@tanstack/react-query';
import { DashboardKPIs, TrendData } from '../types/api';

// Mock data for development
const mockKPIs: DashboardKPIs = {
  brandsTracked: 47,
  competitorsMonitored: 156,
  criticalAlerts: 3,
  regulatoryEvents: 12,
};

const mockTrendData: TrendData[] = [
  { date: '2024-01-01', brand: 'Keytruda', activity: 85 },
  { date: '2024-01-02', brand: 'Keytruda', activity: 92 },
  { date: '2024-01-03', brand: 'Keytruda', activity: 78 },
  { date: '2024-01-04', brand: 'Keytruda', activity: 95 },
  { date: '2024-01-05', brand: 'Keytruda', activity: 88 },
];

const mockYesterdayChanges = [
  {
    brand: 'Keytruda',
    description: 'New Phase III trial initiated in lung cancer'
  },
  {
    brand: 'Opdivo',
    description: 'FDA granted breakthrough therapy designation'
  },
  {
    brand: 'Tecentriq',
    description: 'Competitor patent filing detected'
  }
];

export const useDashboardData = () => {
  const kpisQuery = useQuery({
    queryKey: ['dashboard', 'kpis'],
    queryFn: async (): Promise<{ data: DashboardKPIs }> => {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 500));
      return { data: mockKPIs };
    },
  });

  const trendQuery = useQuery({
    queryKey: ['dashboard', 'trends'],
    queryFn: async (): Promise<{ data: TrendData[] }> => {
      await new Promise(resolve => setTimeout(resolve, 500));
      return { data: mockTrendData };
    },
  });

  return {
    kpis: kpisQuery.data?.data,
    trendData: trendQuery.data?.data || [],
    yesterdayChanges: mockYesterdayChanges,
    isLoading: kpisQuery.isLoading || trendQuery.isLoading,
  };
};