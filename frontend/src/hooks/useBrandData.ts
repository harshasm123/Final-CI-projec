import { useQuery } from '@tanstack/react-query';
import { Brand, SearchResult } from '../types/api';

// Mock data
const mockBrands: Brand[] = [
  {
    id: 'keytruda-1',
    name: 'Keytruda',
    molecule: 'Pembrolizumab',
    manufacturer: 'Merck & Co.',
    indications: ['Melanoma', 'Lung Cancer', 'Head and Neck Cancer'],
    competitors: ['Opdivo', 'Tecentriq', 'Imfinzi'],
    riskScore: 75,
    lastUpdated: '2024-01-15T10:30:00Z'
  },
  {
    id: 'opdivo-1',
    name: 'Opdivo',
    molecule: 'Nivolumab',
    manufacturer: 'Bristol Myers Squibb',
    indications: ['Melanoma', 'Lung Cancer', 'Kidney Cancer'],
    competitors: ['Keytruda', 'Tecentriq', 'Imfinzi'],
    riskScore: 68,
    lastUpdated: '2024-01-15T09:15:00Z'
  }
];

export const useBrandSearch = (query: string) => {
  return useQuery({
    queryKey: ['brands', 'search', query],
    queryFn: async (): Promise<{ data: SearchResult[] }> => {
      if (!query || query.length < 2) {
        return { data: [] };
      }
      
      await new Promise(resolve => setTimeout(resolve, 300));
      
      const results = mockBrands
        .filter(brand => 
          brand.name.toLowerCase().includes(query.toLowerCase()) ||
          brand.molecule.toLowerCase().includes(query.toLowerCase())
        )
        .map(brand => ({
          brand,
          relevanceScore: Math.random() * 100
        }));
      
      return { data: results };
    },
    enabled: query.length >= 2,
  });
};

export const useBrandDetails = (brandId?: string) => {
  return useQuery({
    queryKey: ['brands', 'details', brandId],
    queryFn: async (): Promise<{ data: Brand }> => {
      if (!brandId) throw new Error('Brand ID required');
      
      await new Promise(resolve => setTimeout(resolve, 500));
      
      const brand = mockBrands.find(b => b.id === brandId) || mockBrands[0];
      return { data: brand };
    },
    enabled: !!brandId,
  });
};