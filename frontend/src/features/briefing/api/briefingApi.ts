import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: API_BASE_URL,
});

export const briefingApi = {
  getBriefing: async (params: { user_input: string; location: string; date: string; user_name: string }) => {
    const response = await api.post('/api/v1/briefings', params);
    return response.data;
  },
  getSamsungHealth: async () => {
    const response = await api.get('/health/sleep');
    return response.data;
  },
  getHealth: async () => {
    const response = await api.get('/api/v1/health');
    return response.data;
  },
};
