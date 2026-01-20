import React, { useState } from 'react';
import { useParams } from 'react-router-dom';
import {
  Box,
  TextField,
  Autocomplete,
  Tabs,
  Tab,
  Typography,
  Card,
  CardContent,
  Grid,
  Chip,
  Paper,
} from '@mui/material';
import { Search } from '@mui/icons-material';
import { useBrandSearch, useBrandDetails } from '../hooks/useBrandData';
import ClinicalTrialsTab from '../components/ClinicalTrialsTab';
import RegulatoryTab from '../components/RegulatoryTab';
import PatentsTab from '../components/PatentsTab';
import NewsTab from '../components/NewsTab';
import AIInsightsTab from '../components/AIInsightsTab';

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

const TabPanel = ({ children, value, index }: TabPanelProps) => (
  <div hidden={value !== index}>
    {value === index && <Box sx={{ p: 3 }}>{children}</Box>}
  </div>
);

const BrandIntelligence: React.FC = () => {
  const { brandId } = useParams();
  const [selectedBrand, setSelectedBrand] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [tabValue, setTabValue] = useState(0);

  const { data: searchResults, isLoading: searchLoading } = useBrandSearch(searchQuery);
  const { data: brandDetails, isLoading: detailsLoading } = useBrandDetails(selectedBrand || brandId);

  const handleTabChange = (event: React.SyntheticEvent, newValue: number) => {
    setTabValue(newValue);
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Brand Intelligence
      </Typography>

      {/* Search Bar */}
      <Paper sx={{ p: 3, mb: 3 }}>
        <Autocomplete
          options={searchResults?.data || []}
          getOptionLabel={(option) => option.brand.name}
          loading={searchLoading}
          onInputChange={(event, newInputValue) => {
            setSearchQuery(newInputValue);
          }}
          onChange={(event, newValue) => {
            if (newValue) {
              setSelectedBrand(newValue.brand.id);
            }
          }}
          renderInput={(params) => (
            <TextField
              {...params}
              label="Search by Brand Name or Molecule/INN"
              placeholder="e.g., Keytruda, pembrolizumab"
              InputProps={{
                ...params.InputProps,
                startAdornment: <Search sx={{ mr: 1, color: 'text.secondary' }} />,
              }}
              fullWidth
            />
          )}
          renderOption={(props, option) => (
            <li {...props}>
              <Box>
                <Typography variant="subtitle1">{option.brand.name}</Typography>
                <Typography variant="body2" color="textSecondary">
                  {option.brand.molecule} • {option.brand.manufacturer}
                </Typography>
              </Box>
            </li>
          )}
        />
      </Paper>

      {/* Brand Overview */}
      {brandDetails && (
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Grid container spacing={3}>
              <Grid item xs={12} md={6}>
                <Typography variant="h5" gutterBottom>
                  {brandDetails.data.name}
                </Typography>
                <Typography variant="subtitle1" color="textSecondary" gutterBottom>
                  Molecule: {brandDetails.data.molecule}
                </Typography>
                <Typography variant="body1" gutterBottom>
                  Manufacturer: {brandDetails.data.manufacturer}
                </Typography>
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle2" gutterBottom>
                    Indications:
                  </Typography>
                  <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                    {brandDetails.data.indications.map((indication, index) => (
                      <Chip key={index} label={indication} size="small" />
                    ))}
                  </Box>
                </Box>
              </Grid>
              <Grid item xs={12} md={6}>
                <Typography variant="subtitle2" gutterBottom>
                  Risk Score: {brandDetails.data.riskScore}/100
                </Typography>
                <Box sx={{ mt: 2 }}>
                  <Typography variant="subtitle2" gutterBottom>
                    Key Competitors:
                  </Typography>
                  <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                    {brandDetails.data.competitors.map((competitor, index) => (
                      <Chip key={index} label={competitor} variant="outlined" size="small" />
                    ))}
                  </Box>
                </Box>
              </Grid>
            </Grid>
          </CardContent>
        </Card>
      )}

      {/* Tabs */}
      {brandDetails && (
        <Paper>
          <Tabs value={tabValue} onChange={handleTabChange} variant="scrollable" scrollButtons="auto">
            <Tab label="Overview" />
            <Tab label="Competitive Landscape" />
            <Tab label="Clinical Trials" />
            <Tab label="Regulatory Updates" />
            <Tab label="Patents" />
            <Tab label="News" />
            <Tab label="AI Insights" />
          </Tabs>

          <TabPanel value={tabValue} index={0}>
            <Typography variant="h6">Brand Overview</Typography>
            <Typography>Comprehensive brand analysis and key metrics will be displayed here.</Typography>
          </TabPanel>

          <TabPanel value={tabValue} index={1}>
            <Typography variant="h6">Competitive Landscape</Typography>
            <Typography>Side-by-side competitor comparison will be displayed here.</Typography>
          </TabPanel>

          <TabPanel value={tabValue} index={2}>
            <ClinicalTrialsTab brandId={brandDetails.data.id} />
          </TabPanel>

          <TabPanel value={tabValue} index={3}>
            <RegulatoryTab brandId={brandDetails.data.id} />
          </TabPanel>

          <TabPanel value={tabValue} index={4}>
            <PatentsTab brandId={brandDetails.data.id} />
          </TabPanel>

          <TabPanel value={tabValue} index={5}>
            <NewsTab brandId={brandDetails.data.id} />
          </TabPanel>

          <TabPanel value={tabValue} index={6}>
            <AIInsightsTab brandId={brandDetails.data.id} />
          </TabPanel>
        </Paper>
      )}
    </Box>
  );
};

export default BrandIntelligence;