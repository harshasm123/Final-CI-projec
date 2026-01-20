import React from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
  AppBar,
  Toolbar,
  Typography,
  Button,
  Box,
  Badge,
} from '@mui/material';
import {
  Dashboard,
  Business,
  CompareArrows,
  Notifications,
  Psychology,
  SmartToy,
} from '@mui/icons-material';

const Navbar: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();

  const navItems = [
    { label: 'Dashboard', path: '/', icon: <Dashboard /> },
    { label: 'Brand Intelligence', path: '/brand', icon: <Business /> },
    { label: 'Competitive Landscape', path: '/competitive', icon: <CompareArrows /> },
    { label: 'Alert Center', path: '/alerts', icon: <Notifications /> },
    { label: 'AI Insights', path: '/insights', icon: <Psychology /> },
    { label: 'CI Assistant', path: '/chatbot', icon: <SmartToy /> },
  ];

  return (
    <AppBar position="static">
      <Toolbar>
        <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
          Pharma CI Platform
        </Typography>
        
        <Box sx={{ display: 'flex', gap: 1 }}>
          {navItems.map((item) => (
            <Button
              key={item.path}
              color="inherit"
              startIcon={
                item.path === '/alerts' ? (
                  <Badge badgeContent={3} color="error">
                    {item.icon}
                  </Badge>
                ) : (
                  item.icon
                )
              }
              onClick={() => navigate(item.path)}
              sx={{
                backgroundColor: location.pathname === item.path ? 'rgba(255,255,255,0.1)' : 'transparent',
              }}
            >
              {item.label}
            </Button>
          ))}
        </Box>
      </Toolbar>
    </AppBar>
  );
};

export default Navbar;