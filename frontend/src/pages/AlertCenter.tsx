import React, { useState } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  Chip,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  TextField,
  Badge,
  IconButton,
  Collapse,
} from '@mui/material';
import {
  Warning,
  Error,
  Info,
  ExpandMore,
  ExpandLess,
  FilterList,
} from '@mui/icons-material';
import { useAlerts } from '../hooks/useAlertData';
import { AlertFilters } from '../types/api';

const AlertCenter: React.FC = () => {
  const [filters, setFilters] = useState<AlertFilters>({});
  const [expandedAlert, setExpandedAlert] = useState<string | null>(null);
  const { data: alerts, isLoading } = useAlerts(filters);

  const getSeverityIcon = (severity: string) => {
    switch (severity) {
      case 'critical':
        return <Error color="error" />;
      case 'high':
        return <Warning color="warning" />;
      case 'medium':
        return <Warning color="info" />;
      default:
        return <Info color="action" />;
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'critical':
        return 'error';
      case 'high':
        return 'warning';
      case 'medium':
        return 'info';
      default:
        return 'default';
    }
  };

  const handleExpandAlert = (alertId: string) => {
    setExpandedAlert(expandedAlert === alertId ? null : alertId);
  };

  if (isLoading) {
    return <Typography>Loading alerts...</Typography>;
  }

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">
          Alert Center
        </Typography>
        <Badge badgeContent={alerts?.data?.filter(a => a.severity === 'critical').length || 0} color="error">
          <FilterList />
        </Badge>
      </Box>

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Filters
          </Typography>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Brand</InputLabel>
                <Select
                  value={filters.brand || ''}
                  onChange={(e) => setFilters({ ...filters, brand: e.target.value })}
                >
                  <MenuItem value="">All Brands</MenuItem>
                  <MenuItem value="keytruda">Keytruda</MenuItem>
                  <MenuItem value="opdivo">Opdivo</MenuItem>
                  <MenuItem value="tecentriq">Tecentriq</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Source</InputLabel>
                <Select
                  value={filters.source || ''}
                  onChange={(e) => setFilters({ ...filters, source: e.target.value })}
                >
                  <MenuItem value="">All Sources</MenuItem>
                  <MenuItem value="FDA">FDA</MenuItem>
                  <MenuItem value="EMA">EMA</MenuItem>
                  <MenuItem value="Trials">Clinical Trials</MenuItem>
                  <MenuItem value="Patents">Patents</MenuItem>
                  <MenuItem value="News">News</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Severity</InputLabel>
                <Select
                  value={filters.severity || ''}
                  onChange={(e) => setFilters({ ...filters, severity: e.target.value })}
                >
                  <MenuItem value="">All Severities</MenuItem>
                  <MenuItem value="critical">Critical</MenuItem>
                  <MenuItem value="high">High</MenuItem>
                  <MenuItem value="medium">Medium</MenuItem>
                  <MenuItem value="low">Low</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                fullWidth
                size="small"
                label="Competitor"
                value={filters.competitor || ''}
                onChange={(e) => setFilters({ ...filters, competitor: e.target.value })}
              />
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Alerts List */}
      <Grid container spacing={2}>
        {alerts?.data?.map((alert) => (
          <Grid item xs={12} key={alert.id}>
            <Card 
              sx={{ 
                borderLeft: `4px solid ${
                  alert.severity === 'critical' ? '#f44336' :
                  alert.severity === 'high' ? '#ff9800' :
                  alert.severity === 'medium' ? '#2196f3' : '#4caf50'
                }`
              }}
            >
              <CardContent>
                <Box display="flex" justifyContent="space-between" alignItems="flex-start">
                  <Box flex={1}>
                    <Box display="flex" alignItems="center" gap={1} mb={1}>
                      {getSeverityIcon(alert.severity)}
                      <Typography variant="h6">
                        {alert.title}
                      </Typography>
                      <Chip 
                        label={alert.severity.toUpperCase()} 
                        size="small" 
                        color={getSeverityColor(alert.severity) as any}
                      />
                      <Chip 
                        label={alert.source} 
                        size="small" 
                        variant="outlined"
                      />
                    </Box>
                    
                    <Typography variant="body2" color="textSecondary" gutterBottom>
                      {alert.description}
                    </Typography>
                    
                    <Box display="flex" flexWrap="wrap" gap={1} mb={2}>
                      {alert.brandImpacted.map((brand, index) => (
                        <Chip key={index} label={brand} size="small" color="primary" />
                      ))}
                    </Box>
                    
                    <Box display="flex" justifyContent="space-between" alignItems="center">
                      <Typography variant="caption" color="textSecondary">
                        {new Date(alert.createdAt).toLocaleString()} • Confidence: {alert.confidenceScore}%
                      </Typography>
                      <IconButton 
                        size="small" 
                        onClick={() => handleExpandAlert(alert.id)}
                      >
                        {expandedAlert === alert.id ? <ExpandLess /> : <ExpandMore />}
                      </IconButton>
                    </Box>
                  </Box>
                </Box>
                
                <Collapse in={expandedAlert === alert.id}>
                  <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
                    <Typography variant="subtitle2" gutterBottom>
                      Why It Matters:
                    </Typography>
                    <Typography variant="body2" paragraph>
                      {alert.whyItMatters}
                    </Typography>
                    
                    <Typography variant="subtitle2" gutterBottom>
                      Recommended Actions:
                    </Typography>
                    <Typography variant="body2">
                      • Monitor competitor response within 48 hours
                      • Update competitive positioning analysis
                      • Brief executive team on implications
                    </Typography>
                  </Box>
                </Collapse>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
};

export default AlertCenter;