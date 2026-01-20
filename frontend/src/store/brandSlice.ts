import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { Brand, SearchResult } from '../types/api';

interface BrandState {
  selectedBrand: Brand | null;
  searchResults: SearchResult[];
  searchLoading: boolean;
  competitors: Brand[];
}

const initialState: BrandState = {
  selectedBrand: null,
  searchResults: [],
  searchLoading: false,
  competitors: [],
};

const brandSlice = createSlice({
  name: 'brand',
  initialState,
  reducers: {
    setSelectedBrand: (state, action: PayloadAction<Brand>) => {
      state.selectedBrand = action.payload;
    },
    setSearchResults: (state, action: PayloadAction<SearchResult[]>) => {
      state.searchResults = action.payload;
    },
    setSearchLoading: (state, action: PayloadAction<boolean>) => {
      state.searchLoading = action.payload;
    },
    setCompetitors: (state, action: PayloadAction<Brand[]>) => {
      state.competitors = action.payload;
    },
  },
});

export const { setSelectedBrand, setSearchResults, setSearchLoading, setCompetitors } = brandSlice.actions;
export default brandSlice.reducer;