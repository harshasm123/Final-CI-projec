import React from 'react';
import { Typography, Box } from '@mui/material';

interface NewsTabProps {
  brandId: string;
}

const NewsTab: React.FC<NewsTabProps> = ({ brandId }) => (
  <Box>
    <Typography variant="h6" gutterBottom>News</Typography>
    <Typography>News and market intelligence for {brandId} will be displayed here.</Typography>
  </Box>
);

export default NewsTab;