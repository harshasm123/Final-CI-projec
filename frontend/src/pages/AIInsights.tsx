import React, { useState } from 'react';
import {
  Box,
  Typography,
  TextField,
  Button,
  Card,
  CardContent,
  Paper,
  Chip,
  IconButton,
  List,
  ListItem,
  ListItemText,
  Divider,
} from '@mui/material';
import {
  Send,
  Psychology,
  Source,
  TrendingUp,
} from '@mui/icons-material';
import { useAIInsights } from '../hooks/useAIData';

const AIInsights: React.FC = () => {
  const [question, setQuestion] = useState('');
  const [chatHistory, setChatHistory] = useState<any[]>([]);
  const { mutate: askQuestion, isLoading } = useAIInsights();

  const suggestedQuestions = [
    "Compare Keytruda vs Opdivo in oncology market share",
    "Which competitor is closest to approval in immunotherapy?",
    "What are the key safety signals for PD-1 inhibitors?",
    "Analyze patent expiration risks for top cancer drugs",
    "Show me competitive landscape for CAR-T therapies"
  ];

  const handleSubmitQuestion = () => {
    if (!question.trim()) return;

    const newQuestion = {
      id: Date.now(),
      question,
      timestamp: new Date(),
      isUser: true
    };

    setChatHistory(prev => [...prev, newQuestion]);

    askQuestion(
      { question, context: '' },
      {
        onSuccess: (response) => {
          const aiResponse = {
            id: Date.now() + 1,
            question: response.data.question,
            answer: response.data.answer,
            sources: response.data.sources,
            confidenceScore: response.data.confidenceScore,
            timestamp: new Date(),
            isUser: false
          };
          setChatHistory(prev => [...prev, aiResponse]);
        }
      }
    );

    setQuestion('');
  };

  const handleSuggestedQuestion = (suggestedQ: string) => {
    setQuestion(suggestedQ);
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        AI Insights & Chat
      </Typography>

      <Box display="flex" gap={3}>
        {/* Chat Interface */}
        <Box flex={2}>
          <Paper sx={{ height: '600px', display: 'flex', flexDirection: 'column' }}>
            {/* Chat Messages */}
            <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
              {chatHistory.length === 0 ? (
                <Box 
                  display="flex" 
                  flexDirection="column" 
                  alignItems="center" 
                  justifyContent="center" 
                  height="100%"
                  color="text.secondary"
                >
                  <Psychology sx={{ fontSize: 64, mb: 2 }} />
                  <Typography variant="h6" gutterBottom>
                    Ask me anything about pharmaceutical intelligence
                  </Typography>
                  <Typography variant="body2" textAlign="center">
                    I can help you analyze competitors, compare brands, assess market opportunities, and more.
                  </Typography>
                </Box>
              ) : (
                <List>
                  {chatHistory.map((item, index) => (
                    <React.Fragment key={item.id}>
                      <ListItem alignItems="flex-start">
                        <ListItemText
                          primary={
                            <Box display="flex" alignItems="center" gap={1}>
                              <Typography variant="subtitle2">
                                {item.isUser ? 'You' : 'AI Assistant'}
                              </Typography>
                              <Typography variant="caption" color="textSecondary">
                                {item.timestamp.toLocaleTimeString()}
                              </Typography>
                              {!item.isUser && (
                                <Chip 
                                  label={`${item.confidenceScore}% confidence`} 
                                  size="small" 
                                  color="primary"
                                />
                              )}
                            </Box>
                          }
                          secondary={
                            <Box sx={{ mt: 1 }}>
                              <Typography variant="body1">
                                {item.isUser ? item.question : item.answer}
                              </Typography>
                              {!item.isUser && item.sources && (
                                <Box sx={{ mt: 2 }}>
                                  <Typography variant="caption" color="textSecondary">
                                    Sources:
                                  </Typography>
                                  <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5, mt: 0.5 }}>
                                    {item.sources.map((source: string, idx: number) => (
                                      <Chip 
                                        key={idx} 
                                        label={source} 
                                        size="small" 
                                        variant="outlined"
                                        icon={<Source />}
                                      />
                                    ))}
                                  </Box>
                                </Box>
                              )}
                            </Box>
                          }
                        />
                      </ListItem>
                      {index < chatHistory.length - 1 && <Divider />}
                    </React.Fragment>
                  ))}
                </List>
              )}
            </Box>

            {/* Input Area */}
            <Box sx={{ p: 2, borderTop: 1, borderColor: 'divider' }}>
              <Box display="flex" gap={1}>
                <TextField
                  fullWidth
                  multiline
                  maxRows={3}
                  placeholder="Ask about competitive intelligence, market analysis, or brand comparisons..."
                  value={question}
                  onChange={(e) => setQuestion(e.target.value)}
                  onKeyPress={(e) => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault();
                      handleSubmitQuestion();
                    }
                  }}
                  disabled={isLoading}
                />
                <IconButton 
                  color="primary" 
                  onClick={handleSubmitQuestion}
                  disabled={!question.trim() || isLoading}
                >
                  <Send />
                </IconButton>
              </Box>
            </Box>
          </Paper>
        </Box>

        {/* Sidebar */}
        <Box flex={1}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Suggested Questions
              </Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                {suggestedQuestions.map((q, index) => (
                  <Button
                    key={index}
                    variant="outlined"
                    size="small"
                    onClick={() => handleSuggestedQuestion(q)}
                    sx={{ textAlign: 'left', justifyContent: 'flex-start' }}
                  >
                    {q}
                  </Button>
                ))}
              </Box>
            </CardContent>
          </Card>

          <Card sx={{ mt: 2 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Quick Analytics
              </Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <Box>
                  <Typography variant="subtitle2" gutterBottom>
                    <TrendingUp sx={{ fontSize: 16, mr: 1 }} />
                    Trending Topics
                  </Typography>
                  <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                    <Chip label="CAR-T Therapy" size="small" />
                    <Chip label="Biosimilars" size="small" />
                    <Chip label="FDA Approvals" size="small" />
                  </Box>
                </Box>
                
                <Box>
                  <Typography variant="subtitle2" gutterBottom>
                    Recent Insights
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    • 3 new competitive threats identified
                    • 2 patent expirations approaching
                    • 5 clinical trial updates
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Box>
      </Box>
    </Box>
  );
};

export default AIInsights;