import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
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

function App() {
  return (
    <Provider store={store}>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider theme={theme}>
          <CssBaseline />
          <Router>
            <Box sx={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
              <Navbar />
              <Box component="main" sx={{ flexGrow: 1, p: 3 }}>
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