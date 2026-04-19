import axios from 'axios';
import { API_BASE_URL } from '../../../lib/config';

const api = axios.create({
  baseURL: API_BASE_URL,
});

export const briefingApi = {
  getBriefing: async (params: { user_input: string; location: string; date: string; user_name: string }) => {
    const response = await api.post('/briefings', params);
    return response.data;
  },
  getHealth: async () => {
    const response = await api.get('/health');
    return response.data;
  },
};
