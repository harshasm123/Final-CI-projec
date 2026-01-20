// API Response Types
export interface ApiResponse<T> {
  data: T;
  success: boolean;
  message?: string;
}

// Brand Intelligence Types
export interface Brand {
  id: string;
  name: string;
  molecule: string;
  manufacturer: string;
  indications: string[];
  competitors: string[];
  riskScore: number;
  lastUpdated: string;
}

export interface CompetitiveLandscape {
  brand: string;
  molecule: string;
  indication: string;
  trialPhase: string;
  trialCount: number;
  recentApproval?: string;
  riskScore: number;
}

// Dashboard Types
export interface DashboardKPIs {
  brandsTracked: number;
  competitorsMonitored: number;
  criticalAlerts: number;
  regulatoryEvents: number;
}

export interface TrendData {
  date: string;
  brand: string;
  activity: number;
}

// Alert Types
export interface Alert {
  id: string;
  title: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  source: 'FDA' | 'EMA' | 'Trials' | 'Patents' | 'News';
  brandImpacted: string[];
  description: string;
  whyItMatters: string;
  createdAt: string;
  confidenceScore: number;
}

// Clinical Trial Types
export interface ClinicalTrial {
  id: string;
  title: string;
  phase: string;
  status: string;
  indication: string;
  sponsor: string;
  startDate: string;
  estimatedCompletion: string;
  participantCount: number;
}

// Patent Types
export interface Patent {
  id: string;
  title: string;
  assignee: string;
  filingDate: string;
  publicationDate: string;
  status: string;
  claims: string[];
}

// News Types
export interface NewsItem {
  id: string;
  title: string;
  source: string;
  publishedAt: string;
  summary: string;
  sentiment: 'positive' | 'neutral' | 'negative';
  relevanceScore: number;
}

// AI Insights Types
export interface AIInsight {
  id: string;
  question: string;
  answer: string;
  sources: string[];
  confidenceScore: number;
  createdAt: string;
}

// Search Types
export interface SearchResult {
  brand: Brand;
  relevanceScore: number;
}

// API Endpoints Interface
export interface ApiEndpoints {
  // Dashboard
  getDashboardKPIs: () => Promise<ApiResponse<DashboardKPIs>>;
  getTrendData: (timeRange: string) => Promise<ApiResponse<TrendData[]>>;
  
  // Brand Intelligence
  searchBrands: (query: string) => Promise<ApiResponse<SearchResult[]>>;
  getBrandDetails: (brandId: string) => Promise<ApiResponse<Brand>>;
  getCompetitiveLandscape: (brandId: string) => Promise<ApiResponse<CompetitiveLandscape[]>>;
  
  // Clinical Trials
  getClinicalTrials: (brandId: string) => Promise<ApiResponse<ClinicalTrial[]>>;
  
  // Regulatory
  getRegulatoryUpdates: (brandId: string) => Promise<ApiResponse<NewsItem[]>>;
  
  // Patents
  getPatents: (brandId: string) => Promise<ApiResponse<Patent[]>>;
  
  // News
  getNews: (brandId: string) => Promise<ApiResponse<NewsItem[]>>;
  
  // Alerts
  getAlerts: (filters?: AlertFilters) => Promise<ApiResponse<Alert[]>>;
  
  // AI Insights
  askQuestion: (question: string, context?: string) => Promise<ApiResponse<AIInsight>>;
}

export interface AlertFilters {
  brand?: string;
  competitor?: string;
  source?: string;
  severity?: string;
  dateRange?: {
    start: string;
    end: string;
  };
}