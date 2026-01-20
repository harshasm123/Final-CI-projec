import React from 'react';
import { Typography, Box } from '@mui/material';

interface ClinicalTrialsTabProps {
  brandId: string;
}

const ClinicalTrialsTab: React.FC<ClinicalTrialsTabProps> = ({ brandId }) => {
  return (
    <Box>
      <Typography variant="h6" gutterBottom>
        Clinical Trials for Brand ID: {brandId}
      </Typography>
      <Typography>
        Clinical trials data and analysis will be displayed here.
      </Typography>
    </Box>
  );
};

export default ClinicalTrialsTab;