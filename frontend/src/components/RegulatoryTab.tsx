import React from 'react';
import { Typography, Box } from '@mui/material';

interface RegulatoryTabProps {
  brandId: string;
}

export const RegulatoryTab: React.FC<RegulatoryTabProps> = ({ brandId }) => (
  <Box>
    <Typography variant="h6" gutterBottom>Regulatory Updates</Typography>
    <Typography>Regulatory updates for {brandId} will be displayed here.</Typography>
  </Box>
);

interface PatentsTabProps {
  brandId: string;
}

export const PatentsTab: React.FC<PatentsTabProps> = ({ brandId }) => (
  <Box>
    <Typography variant="h6" gutterBottom>Patents</Typography>
    <Typography>Patent information for {brandId} will be displayed here.</Typography>
  </Box>
);

interface NewsTabProps {
  brandId: string;
}

export const NewsTab: React.FC<NewsTabProps> = ({ brandId }) => (
  <Box>
    <Typography variant="h6" gutterBottom>News</Typography>
    <Typography>News and market intelligence for {brandId} will be displayed here.</Typography>
  </Box>
);

interface AIInsightsTabProps {
  brandId: string;
}

export const AIInsightsTab: React.FC<AIInsightsTabProps> = ({ brandId }) => (
  <Box>
    <Typography variant="h6" gutterBottom>AI Insights</Typography>
    <Typography>AI-generated insights for {brandId} will be displayed here.</Typography>
  </Box>
);

export default RegulatoryTab;