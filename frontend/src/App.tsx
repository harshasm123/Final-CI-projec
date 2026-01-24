import React, { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import { CssBaseline, Box } from '@mui/material';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Provider } from 'react-redux';
import { store } from './store/store';
import Navbar from './components/Navbar';
import Dashboard from './pages/Dashboard';
import BrandIntelligence from './pages/BrandIntelligence';
import CompetitiveLandscape from './pages/CompetitiveLandscape';
import AlertCenter from './pages/AlertCenter';
import AIInsights from './pages/AIInsights';
import EnhancedAIChatbot from './components/EnhancedAIChatbot';

const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
  },
});

const queryClient = new QueryClient();

function DocumentTitle() {
  const location = useLocation();
  
  useEffect(() => {
    const titles: { [key: string]: string } = {
      '/': 'Dashboard - Pharma CI Platform',
      '/brand': 'Brand Intelligence - Pharma CI Platform',
      '/competitive': 'Competitive Landscape - Pharma CI Platform',
      '/alerts': 'Alert Center - Pharma CI Platform',
      '/insights': 'AI Insights - Pharma CI Platform',
      '/chatbot': 'AI Chatbot - Pharma CI Platform',
    };
    
    const path = location.pathname.split('/')[1] ? `/${location.pathname.split('/')[1]}` : '/';
    document.title = titles[path] || 'Pharma CI Platform';
  }, [location]);
  
  return null;
}

function App() {
  return (
    <Provider store={store}>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider theme={theme}>
          <CssBaseline />
          <Router>
            <DocumentTitle />
            <Box sx={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
              <Navbar />
              <Box component="main" sx={{ flexGrow: 1, p: 3 }} role="main">
                <Routes>
                  <Route path="/" element={<Dashboard />} />
                  <Route path="/brand/:brandId?" element={<BrandIntelligence />} />
                  <Route path="/competitive" element={<CompetitiveLandscape />} />
                  <Route path="/alerts" element={<AlertCenter />} />
                  <Route path="/insights" element={<AIInsights />} />
                  <Route path="/chatbot" element={<EnhancedAIChatbot />} />
                </Routes>
              </Box>
            </Box>
          </Router>
        </ThemeProvider>
      </QueryClientProvider>
    </Provider>
  );
}

export default App;