import React, { useState } from 'react';
import {
  Box,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Grid,
  Card,
  CardContent,
  Chip,
} from '@mui/material';
import { Radar, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, ResponsiveContainer, Timeline } from 'recharts';
import { useCompetitiveLandscape } from '../hooks/useCompetitiveData';

const CompetitiveLandscape: React.FC = () => {
  const [selectedBrands, setSelectedBrands] = useState<string[]>(['brand1', 'brand2']);
  const { data: competitiveData, isLoading } = useCompetitiveLandscape(selectedBrands);

  const radarData = [
    { subject: 'Clinical Momentum', A: 120, B: 110, fullMark: 150 },
    { subject: 'Regulatory Proximity', A: 98, B: 130, fullMark: 150 },
    { subject: 'Patent Activity', A: 86, B: 130, fullMark: 150 },
    { subject: 'Safety Signals', A: 99, B: 100, fullMark: 150 },
    { subject: 'News Sentiment', A: 85, B: 90, fullMark: 150 },
  ];

  const heatmapData = [
    { brand: 'Keytruda', oncology: 95, immunology: 20, cardiology: 5 },
    { brand: 'Opdivo', oncology: 85, immunology: 30, cardiology: 10 },
    { brand: 'Tecentriq', oncology: 75, immunology: 15, cardiology: 5 },
  ];

  if (isLoading) {
    return <Typography>Loading competitive landscape...</Typography>;
  }

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Competitive Landscape
      </Typography>

      {/* Comparison Table */}
      <Paper sx={{ mb: 4 }}>
        <Typography variant="h6" sx={{ p: 2 }}>
          Brand Comparison Matrix
        </Typography>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Brand</TableCell>
                <TableCell>Molecule</TableCell>
                <TableCell>Indication</TableCell>
                <TableCell>Trial Phase</TableCell>
                <TableCell>Trial Count</TableCell>
                <TableCell>Recent Approval</TableCell>
                <TableCell>Risk Score</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {competitiveData?.data?.map((row, index) => (
                <TableRow key={index}>
                  <TableCell>
                    <Typography variant="subtitle2">{row.brand}</Typography>
                  </TableCell>
                  <TableCell>{row.molecule}</TableCell>
                  <TableCell>
                    <Chip label={row.indication} size="small" />
                  </TableCell>
                  <TableCell>
                    <Chip 
                      label={row.trialPhase} 
                      size="small" 
                      color={row.trialPhase.includes('III') ? 'error' : 'default'}
                    />
                  </TableCell>
                  <TableCell>{row.trialCount}</TableCell>
                  <TableCell>{row.recentApproval || 'N/A'}</TableCell>
                  <TableCell>
                    <Chip 
                      label={row.riskScore} 
                      size="small"
                      color={row.riskScore > 70 ? 'error' : row.riskScore > 40 ? 'warning' : 'success'}
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      {/* Visualizations */}
      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Competitive Strength Radar
              </Typography>
              <ResponsiveContainer width="100%" height={300}>
                <RadarChart data={radarData}>
                  <PolarGrid />
                  <PolarAngleAxis dataKey="subject" />
                  <PolarRadiusAxis angle={90} domain={[0, 150]} />
                  <Radar name="Brand A" dataKey="A" stroke="#8884d8" fill="#8884d8" fillOpacity={0.6} />
                  <Radar name="Brand B" dataKey="B" stroke="#82ca9d" fill="#82ca9d" fillOpacity={0.6} />
                </RadarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Activity Intensity Heatmap
              </Typography>
              <Box sx={{ mt: 2 }}>
                {heatmapData.map((brand, index) => (
                  <Box key={index} sx={{ mb: 2 }}>
                    <Typography variant="subtitle2">{brand.brand}</Typography>
                    <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
                      <Chip 
                        label={`Oncology: ${brand.oncology}%`} 
                        size="small" 
                        sx={{ bgcolor: `rgba(255, 0, 0, ${brand.oncology / 100})` }}
                      />
                      <Chip 
                        label={`Immunology: ${brand.immunology}%`} 
                        size="small"
                        sx={{ bgcolor: `rgba(0, 255, 0, ${brand.immunology / 100})` }}
                      />
                      <Chip 
                        label={`Cardiology: ${brand.cardiology}%`} 
                        size="small"
                        sx={{ bgcolor: `rgba(0, 0, 255, ${brand.cardiology / 100})` }}
                      />
                    </Box>
                  </Box>
                ))}
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Timeline Comparison - Key Events by Brand
              </Typography>
              <Box sx={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Typography color="textSecondary">
                  Timeline visualization will be implemented here
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default CompetitiveLandscape;