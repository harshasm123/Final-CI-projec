import { useMutation } from '@tanstack/react-query';
import { AIInsight } from '../types/api';

const mockAIResponses: Record<string, string> = {
  'keytruda': 'Keytruda (pembrolizumab) maintains market leadership in PD-1 inhibitors with 847 active trials and strong performance across multiple indications including melanoma, lung cancer, and head & neck cancer.',
  'opdivo': 'Opdivo (nivolumab) shows competitive strength with 623 active trials, particularly in combination therapies and emerging indications like kidney cancer.',
  'compare': 'Keytruda leads in trial volume and market share, while Opdivo excels in combination strategies. Both face increasing competition from newer entrants like Tecentriq.',
  'default': 'Based on current competitive intelligence data, I can provide insights on brand performance, market dynamics, clinical trial landscapes, and competitive positioning.'
};

export const useAIInsights = () => {
  return useMutation({
    mutationFn: async ({ question, context }: { question: string; context?: string }): Promise<{ data: AIInsight }> => {
      // Simulate AI processing time
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      // Simple keyword matching for demo
      let answer = mockAIResponses.default;
      const lowerQuestion = question.toLowerCase();
      
      if (lowerQuestion.includes('keytruda')) {
        answer = mockAIResponses.keytruda;
      } else if (lowerQuestion.includes('opdivo')) {
        answer = mockAIResponses.opdivo;
      } else if (lowerQuestion.includes('compare') || lowerQuestion.includes('vs')) {
        answer = mockAIResponses.compare;
      }
      
      const insight: AIInsight = {
        id: `insight-${Date.now()}`,
        question,
        answer,
        sources: ['ClinicalTrials.gov', 'FDA Database', 'PubMed', 'Patent Database'],
        confidenceScore: Math.floor(Math.random() * 20) + 80, // 80-100%
        createdAt: new Date().toISOString()
      };
      
      return { data: insight };
    },
  });
};