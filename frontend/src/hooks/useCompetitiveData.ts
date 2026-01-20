import { useQuery } from '@tanstack/react-query';
import { CompetitiveLandscape } from '../types/api';

const mockCompetitiveData: CompetitiveLandscape[] = [
  {
    brand: 'Keytruda',
    molecule: 'Pembrolizumab',
    indication: 'Melanoma',
    trialPhase: 'Phase III',
    trialCount: 847,
    recentApproval: '2024-01-10',
    riskScore: 75
  },
  {
    brand: 'Opdivo',
    molecule: 'Nivolumab',
    indication: 'Lung Cancer',
    trialPhase: 'Phase III',
    trialCount: 623,
    recentApproval: '2023-12-15',
    riskScore: 68
  },
  {
    brand: 'Tecentriq',
    molecule: 'Atezolizumab',
    indication: 'Bladder Cancer',
    trialPhase: 'Phase II',
    trialCount: 412,
    riskScore: 52
  }
];

export const useCompetitiveLandscape = (brandIds: string[]) => {
  return useQuery({
    queryKey: ['competitive', 'landscape', brandIds],
    queryFn: async (): Promise<{ data: CompetitiveLandscape[] }> => {
      await new Promise(resolve => setTimeout(resolve, 800));
      return { data: mockCompetitiveData };
    },
    enabled: brandIds.length > 0,
  });
};