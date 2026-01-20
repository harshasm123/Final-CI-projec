import { useQuery } from '@tanstack/react-query';
import { Alert, AlertFilters } from '../types/api';

const mockAlerts: Alert[] = [
  {
    id: 'alert-1',
    title: 'FDA Approves Competitor Drug for Same Indication',
    severity: 'critical',
    source: 'FDA',
    brandImpacted: ['Keytruda'],
    description: 'FDA has approved a new PD-1 inhibitor for melanoma treatment, directly competing with Keytruda.',
    whyItMatters: 'This approval creates direct competition in the melanoma market, potentially impacting market share and pricing strategies.',
    createdAt: '2024-01-15T08:30:00Z',
    confidenceScore: 95
  },
  {
    id: 'alert-2',
    title: 'Patent Challenge Filed Against Key Competitor',
    severity: 'high',
    source: 'Patents',
    brandImpacted: ['Opdivo'],
    description: 'Generic manufacturer has filed patent challenge against Opdivo formulation patent.',
    whyItMatters: 'Successful challenge could lead to earlier generic entry, affecting competitive dynamics.',
    createdAt: '2024-01-15T07:15:00Z',
    confidenceScore: 87
  },
  {
    id: 'alert-3',
    title: 'Positive Phase III Results Announced',
    severity: 'medium',
    source: 'Trials',
    brandImpacted: ['Tecentriq'],
    description: 'Competitor announced positive Phase III results in combination therapy for lung cancer.',
    whyItMatters: 'Could lead to expanded label and increased market competition.',
    createdAt: '2024-01-15T06:45:00Z',
    confidenceScore: 78
  }
];

export const useAlerts = (filters?: AlertFilters) => {
  return useQuery({
    queryKey: ['alerts', filters],
    queryFn: async (): Promise<{ data: Alert[] }> => {
      await new Promise(resolve => setTimeout(resolve, 400));
      
      let filteredAlerts = mockAlerts;
      
      if (filters?.severity) {
        filteredAlerts = filteredAlerts.filter(alert => alert.severity === filters.severity);
      }
      
      if (filters?.source) {
        filteredAlerts = filteredAlerts.filter(alert => alert.source === filters.source);
      }
      
      if (filters?.brand) {
        filteredAlerts = filteredAlerts.filter(alert => 
          alert.brandImpacted.some(brand => 
            brand.toLowerCase().includes(filters.brand!.toLowerCase())
          )
        );
      }
      
      return { data: filteredAlerts };
    },
  });
};