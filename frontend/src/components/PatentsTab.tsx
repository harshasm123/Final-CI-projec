import React from 'react';
import { Typography, Box } from '@mui/material';

interface PatentsTabProps {
  brandId: string;
}

const PatentsTab: React.FC<PatentsTabProps> = ({ brandId }) => (
  <Box>
    <Typography variant="h6" gutterBottom>Patents</Typography>
    <Typography>Patent information for {brandId} will be displayed here.</Typography>
  </Box>
);

export default PatentsTab;