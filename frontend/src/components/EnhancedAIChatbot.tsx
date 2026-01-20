import React, { useState, useRef, useEffect } from 'react';
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
  Avatar,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  LinearProgress,
} from '@mui/material';
import {
  Send,
  Psychology,
  Source,
  TrendingUp,
  ExpandMore,
  SmartToy,
  Person,
  Analytics,
  Biotech,
  Gavel,
  Assignment,
} from '@mui/icons-material';
import { useEnhancedAI } from '../hooks/useEnhancedAI';

interface ChatMessage {
  id: string;
  type: 'user' | 'agent';
  content: string;
  timestamp: Date;
  sources?: string[];
  citations?: Array<{source: string; content: string}>;
  confidenceScore?: number;
  sessionId?: string;
  agentUsed?: boolean;
  analysisType?: string;
}

const EnhancedAIChatbot: React.FC = () => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [sessionId] = useState(`session-${Date.now()}`);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  const { mutate: askAgent, isLoading } = useEnhancedAI();

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // Enhanced CI analysis prompts
  const ciAnalysisPrompts = [
    {
      category: 'Competitive Analysis',
      icon: <Analytics />,
      prompts: [
        "Analyze the competitive landscape for Keytruda in oncology",
        "Compare market positioning of PD-1 inhibitors",
        "What are the key competitive threats to Opdivo?",
        "Assess competitive strength of Tecentriq vs market leaders"
      ]
    },
    {
      category: 'Clinical Intelligence',
      icon: <Biotech />,
      prompts: [
        "What Phase III trials pose the biggest competitive threat?",
        "Analyze clinical trial momentum for immunotherapy brands",
        "Which competitors are closest to regulatory approval?",
        "Assess pipeline strength in cancer immunotherapy"
      ]
    },
    {
      category: 'Regulatory Intelligence',
      icon: <Gavel />,
      prompts: [
        "What recent FDA approvals impact our competitive position?",
        "Analyze regulatory risk for key competitor brands",
        "What safety signals should we monitor?",
        "Assess patent expiration impact on market dynamics"
      ]
    },
    {
      category: 'Strategic Intelligence',
      icon: <Assignment />,
      prompts: [
        "What market opportunities exist in emerging indications?",
        "Analyze competitive response to our latest launch",
        "What are the key investment priorities for competitive advantage?",
        "Assess M&A activity impact on competitive landscape"
      ]
    }
  ];

  const handleSendMessage = () => {
    if (!inputMessage.trim() || isLoading) return;

    const userMessage: ChatMessage = {
      id: `user-${Date.now()}`,
      type: 'user',
      content: inputMessage,
      timestamp: new Date(),
      sessionId
    };

    setMessages(prev => [...prev, userMessage]);

    askAgent(
      { 
        question: inputMessage, 
        sessionId,
        context: 'enhanced_ci_analysis'
      },
      {
        onSuccess: (response) => {
          const agentMessage: ChatMessage = {
            id: `agent-${Date.now()}`,
            type: 'agent',
            content: response.data.answer,
            timestamp: new Date(),
            sources: response.data.sources,
            citations: response.data.citations,
            confidenceScore: response.data.confidenceScore,
            sessionId: response.data.sessionId,
            agentUsed: response.data.agentUsed,
            analysisType: determineAnalysisType(inputMessage)
          };
          setMessages(prev => [...prev, agentMessage]);
        },
        onError: (error) => {
          const errorMessage: ChatMessage = {
            id: `error-${Date.now()}`,
            type: 'agent',
            content: 'I apologize, but I encountered an error processing your request. Please try again or rephrase your question.',
            timestamp: new Date(),
            confidenceScore: 0
          };
          setMessages(prev => [...prev, errorMessage]);
        }
      }
    );

    setInputMessage('');
  };

  const determineAnalysisType = (question: string): string => {
    const lowerQ = question.toLowerCase();
    if (lowerQ.includes('competitive') || lowerQ.includes('competitor')) return 'Competitive Analysis';
    if (lowerQ.includes('trial') || lowerQ.includes('clinical')) return 'Clinical Intelligence';
    if (lowerQ.includes('fda') || lowerQ.includes('regulatory')) return 'Regulatory Intelligence';
    if (lowerQ.includes('market') || lowerQ.includes('strategy')) return 'Strategic Intelligence';
    return 'General Analysis';
  };

  const handlePromptClick = (prompt: string) => {
    setInputMessage(prompt);
  };

  const renderMessage = (message: ChatMessage) => (
    <Box
      key={message.id}
      sx={{
        display: 'flex',
        justifyContent: message.type === 'user' ? 'flex-end' : 'flex-start',
        mb: 2
      }}
    >
      <Box
        sx={{
          maxWidth: '80%',
          display: 'flex',
          alignItems: 'flex-start',
          gap: 1,
          flexDirection: message.type === 'user' ? 'row-reverse' : 'row'
        }}
      >
        <Avatar
          sx={{
            bgcolor: message.type === 'user' ? 'primary.main' : 'secondary.main',
            width: 32,
            height: 32
          }}
        >
          {message.type === 'user' ? <Person /> : <SmartToy />}
        </Avatar>
        
        <Card
          sx={{
            bgcolor: message.type === 'user' ? 'primary.light' : 'grey.100',
            color: message.type === 'user' ? 'primary.contrastText' : 'text.primary'
          }}
        >
          <CardContent sx={{ p: 2, '&:last-child': { pb: 2 } }}>
            {message.type === 'agent' && message.analysisType && (
              <Chip
                label={message.analysisType}
                size="small"
                sx={{ mb: 1 }}
                color="primary"
              />
            )}
            
            <Typography variant="body1" sx={{ mb: 1 }}>
              {message.content}
            </Typography>
            
            {message.type === 'agent' && (
              <Box sx={{ mt: 2 }}>
                {message.confidenceScore && (
                  <Box sx={{ mb: 1 }}>
                    <Typography variant="caption" color="textSecondary">
                      Confidence: {message.confidenceScore}%
                    </Typography>
                    <LinearProgress
                      variant="determinate"
                      value={message.confidenceScore}
                      sx={{ height: 4, borderRadius: 2 }}
                    />
                  </Box>
                )}
                
                {message.agentUsed && (
                  <Chip
                    label="AI Agent Enhanced"
                    size="small"
                    color="success"
                    icon={<Psychology />}
                    sx={{ mr: 1, mb: 1 }}
                  />
                )}
                
                {message.sources && message.sources.length > 0 && (
                  <Accordion sx={{ mt: 1 }}>
                    <AccordionSummary expandIcon={<ExpandMore />}>
                      <Typography variant="caption">
                        Sources ({message.sources.length})
                      </Typography>
                    </AccordionSummary>
                    <AccordionDetails>
                      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                        {message.sources.map((source, idx) => (
                          <Chip
                            key={idx}
                            label={source}
                            size="small"
                            variant="outlined"
                            icon={<Source />}
                          />
                        ))}
                      </Box>
                      
                      {message.citations && message.citations.length > 0 && (
                        <Box sx={{ mt: 2 }}>
                          <Typography variant="caption" color="textSecondary">
                            Key Citations:
                          </Typography>
                          {message.citations.slice(0, 3).map((citation, idx) => (
                            <Typography
                              key={idx}
                              variant="body2"
                              sx={{ mt: 1, p: 1, bgcolor: 'grey.50', borderRadius: 1 }}
                            >
                              "{citation.content}"
                            </Typography>
                          ))}
                        </Box>
                      )}
                    </AccordionDetails>
                  </Accordion>
                )}
              </Box>
            )}
            
            <Typography variant="caption" color="textSecondary" sx={{ mt: 1, display: 'block' }}>
              {message.timestamp.toLocaleTimeString()}
            </Typography>
          </CardContent>
        </Card>
      </Box>
    </Box>
  );

  return (
    <Box sx={{ height: '100vh', display: 'flex' }}>
      {/* Main Chat Area */}
      <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        <Paper sx={{ p: 2, borderBottom: 1, borderColor: 'divider' }}>
          <Typography variant="h5" gutterBottom>
            <Psychology sx={{ mr: 1, verticalAlign: 'middle' }} />
            CI Analysis Assistant
          </Typography>
          <Typography variant="body2" color="textSecondary">
            Your AI-powered competitive intelligence analyst. Ask about market dynamics, competitive threats, clinical landscapes, and strategic opportunities.
          </Typography>
        </Paper>

        {/* Messages Area */}
        <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
          {messages.length === 0 ? (
            <Box
              sx={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                height: '100%',
                textAlign: 'center'
              }}
            >
              <Psychology sx={{ fontSize: 64, color: 'primary.main', mb: 2 }} />
              <Typography variant="h6" gutterBottom>
                Welcome to your CI Analysis Assistant
              </Typography>
              <Typography variant="body1" color="textSecondary" sx={{ mb: 3 }}>
                I'm here to help you with pharmaceutical competitive intelligence analysis.
                Ask me about competitive landscapes, clinical trials, regulatory impacts, or strategic opportunities.
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Try asking: "Analyze the competitive threats to Keytruda in oncology"
              </Typography>
            </Box>
          ) : (
            messages.map(renderMessage)
          )}
          
          {isLoading && (
            <Box sx={{ display: 'flex', justifyContent: 'flex-start', mb: 2 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <Avatar sx={{ bgcolor: 'secondary.main', width: 32, height: 32 }}>
                  <SmartToy />
                </Avatar>
                <Card sx={{ bgcolor: 'grey.100' }}>
                  <CardContent sx={{ p: 2 }}>
                    <Typography variant="body2" color="textSecondary">
                      Analyzing your request...
                    </Typography>
                    <LinearProgress sx={{ mt: 1, width: 200 }} />
                  </CardContent>
                </Card>
              </Box>
            </Box>
          )}
          
          <div ref={messagesEndRef} />
        </Box>

        {/* Input Area */}
        <Paper sx={{ p: 2, borderTop: 1, borderColor: 'divider' }}>
          <Box sx={{ display: 'flex', gap: 1 }}>
            <TextField
              fullWidth
              multiline
              maxRows={3}
              placeholder="Ask about competitive intelligence, market analysis, or strategic opportunities..."
              value={inputMessage}
              onChange={(e) => setInputMessage(e.target.value)}
              onKeyPress={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  handleSendMessage();
                }
              }}
              disabled={isLoading}
            />
            <IconButton
              color="primary"
              onClick={handleSendMessage}
              disabled={!inputMessage.trim() || isLoading}
              sx={{ alignSelf: 'flex-end' }}
            >
              <Send />
            </IconButton>
          </Box>
        </Paper>
      </Box>

      {/* Sidebar with Analysis Prompts */}
      <Box sx={{ width: 350, borderLeft: 1, borderColor: 'divider', overflow: 'auto' }}>
        <Paper sx={{ p: 2, borderBottom: 1, borderColor: 'divider' }}>
          <Typography variant="h6" gutterBottom>
            CI Analysis Templates
          </Typography>
          <Typography variant="body2" color="textSecondary">
            Click any prompt to start your analysis
          </Typography>
        </Paper>

        <Box sx={{ p: 2 }}>
          {ciAnalysisPrompts.map((category, categoryIdx) => (
            <Accordion key={categoryIdx} sx={{ mb: 1 }}>
              <AccordionSummary expandIcon={<ExpandMore />}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  {category.icon}
                  <Typography variant="subtitle2">
                    {category.category}
                  </Typography>
                </Box>
              </AccordionSummary>
              <AccordionDetails>
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                  {category.prompts.map((prompt, promptIdx) => (
                    <Button
                      key={promptIdx}
                      variant="outlined"
                      size="small"
                      onClick={() => handlePromptClick(prompt)}
                      sx={{
                        textAlign: 'left',
                        justifyContent: 'flex-start',
                        textTransform: 'none',
                        fontSize: '0.875rem'
                      }}
                    >
                      {prompt}
                    </Button>
                  ))}
                </Box>
              </AccordionDetails>
            </Accordion>
          ))}
        </Box>
      </Box>
    </Box>
  );
};

export default EnhancedAIChatbot;