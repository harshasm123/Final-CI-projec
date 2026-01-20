import React from 'react';
import { Typography, Box } from '@mui/material';

interface AIInsightsTabProps {
  brandId: string;
}

const AIInsightsTab: React.FC<AIInsightsTabProps> = ({ brandId }) => (
  <Box>
    <Typography variant="h6" gutterBottom>AI Insights</Typography>
    <Typography>AI-generated insights for {brandId} will be displayed here.</Typography>
  </Box>
);

export default AIInsightsTab;