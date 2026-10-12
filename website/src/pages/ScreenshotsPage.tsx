import React, { useState } from 'react';
import { useLanguage } from '../context/LanguageContext';
import { screenshotsList } from '../data/screenshotsData';
import { ScreenshotLightbox } from '../components/ScreenshotLightbox';
import type { ScreenshotItem } from '../types';
import { Sun, Moon, Search, Layers, Maximize2 } from 'lucide-react';

export const ScreenshotsPage: React.FC = () => {
  const { lang } = useLanguage();
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [appearanceFilter, setAppearanceFilter] = useState<'both' | 'light' | 'dark'>('both');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [selectedItem, setSelectedItem] = useState<ScreenshotItem | null>(null);

  const categories = [
    { id: 'all', label: lang === 'en' ? 'All Screens' : 'সকল স্ক্রিন' },
    { id: 'telemetry', label: lang === 'en' ? 'System Monitoring' : 'সিস্টেম মনিটরিং' },
    { id: 'developer', label: lang === 'en' ? 'Developer Tools' : 'ডেভেলপার টুলস' },
    { id: 'files', label: lang === 'en' ? 'PDF & Files' : 'পিডিএফ ও ফাইল' },
    { id: 'settings', label: lang === 'en' ? 'Settings' : 'সেটিংস' },
    { id: 'widget', label: lang === 'en' ? 'Widget' : 'মেনু বার উইজেট' },
  ];

  const filteredItems = screenshotsList.filter((item) => {
    const matchesCat = selectedCategory === 'all' || item.category === selectedCategory;
    const q = searchQuery.toLowerCase();
    const matchesSearch =
      item.titleEn.toLowerCase().includes(q) ||
      item.titleBn.toLowerCase().includes(q) ||
      item.descriptionEn.toLowerCase().includes(q) ||
      item.descriptionBn.toLowerCase().includes(q);
    return matchesCat && matchesSearch;
  });

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-10">
      {/* Header */}
      <div className="text-center max-w-3xl mx-auto space-y-4">
        <span className="text-xs font-bold uppercase tracking-widest text-blue-600">
          {lang === 'en' ? '100% Authentic Native UI' : 'প্রকৃত ম্যাক অ্যাপের আসল স্ক্রিনশট'}
        </span>
        <h1 className="text-4xl sm:text-5xl font-extrabold text-gray-950 tracking-tight">
          {lang === 'en' ? 'Screenshot Gallery' : 'স্ক্রিনশট গ্যালারি'}
        </h1>
        <p className="text-base text-gray-600 leading-relaxed">
          {lang === 'en'
            ? 'Every screenshot is captured programmatically from Borno Pulse running natively on macOS. Fully intact windows with uncropped sidebars, traffic light controls, and complete layouts.'
            : 'প্রতিটি স্ক্রিনশট ম্যাকওএসে চলমান আসল Borno Pulse অ্যাপ থেকে স্বয়ংক্রিয়ভাবে সংগৃহীত। সম্পূর্ণ সাইডবার, ট্রাফিক লাইট বাটন ও মেনু অক্ষত রেখে পূর্ণাঙ্গ রূপে প্রদর্শিত।'}
        </p>
      </div>

      {/* Filter Toolbar */}
      <div className="flex flex-col md:flex-row items-center justify-between gap-4 p-4 rounded-2xl bg-white border border-gray-200/90 shadow-xs">
        {/* Category Pills */}
        <div className="flex flex-wrap items-center gap-1.5 w-full md:w-auto">
          {categories.map((cat) => (
            <button
              key={cat.id}
              onClick={() => setSelectedCategory(cat.id)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
                selectedCategory === cat.id
                  ? 'bg-blue-600 text-white shadow-2xs'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>

        {/* Appearance Mode & Search */}
        <div className="flex items-center gap-3 w-full md:w-auto justify-between md:justify-end">
          <div className="flex items-center gap-1 bg-gray-100 rounded-lg p-1 border border-gray-200">
            <button
              onClick={() => setAppearanceFilter('both')}
              className={`px-2.5 py-1 rounded text-xs font-medium transition-colors ${
                appearanceFilter === 'both' ? 'bg-white text-gray-900 shadow-2xs' : 'text-gray-600'
              }`}
            >
              <Layers className="w-3.5 h-3.5 inline mr-1" />
              <span>{lang === 'en' ? 'All' : 'উভয়'}</span>
            </button>
            <button
              onClick={() => setAppearanceFilter('light')}
              className={`px-2.5 py-1 rounded text-xs font-medium transition-colors ${
                appearanceFilter === 'light' ? 'bg-white text-gray-900 shadow-2xs' : 'text-gray-600'
              }`}
            >
              <Sun className="w-3.5 h-3.5 inline mr-1 text-amber-500" />
              <span>Light</span>
            </button>
            <button
              onClick={() => setAppearanceFilter('dark')}
              className={`px-2.5 py-1 rounded text-xs font-medium transition-colors ${
                appearanceFilter === 'dark' ? 'bg-gray-800 text-white shadow-2xs' : 'text-gray-600'
              }`}
            >
              <Moon className="w-3.5 h-3.5 inline mr-1 text-indigo-400" />
              <span>Dark</span>
            </button>
          </div>

          <div className="relative w-48 sm:w-60">
            <Search className="w-3.5 h-3.5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={lang === 'en' ? 'Search gallery...' : 'স্ক্রিন খুঁজুন...'}
              className="w-full pl-8 pr-3 py-1.5 text-xs rounded-lg border border-gray-200 focus:outline-hidden focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
            />
          </div>
        </div>
      </div>

      {/* Grid of Uncropped Screenshots */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredItems.map((item) => {
          const showLight = appearanceFilter === 'both' || appearanceFilter === 'light';
          const showDark = appearanceFilter === 'both' || appearanceFilter === 'dark';
          const currentImg = appearanceFilter === 'dark' ? item.darkSrc : item.lightSrc;

          return (
            <div
              key={item.id}
              onClick={() => setSelectedItem(item)}
              className="group cursor-pointer rounded-2xl bg-white border border-gray-200/90 p-3 shadow-xs hover:shadow-xl transition-all space-y-3 flex flex-col justify-between"
            >
              {/* Screenshot Display Card — Uncropped Object-Contain */}
              <div className="relative w-full rounded-xl bg-gray-950/5 border border-gray-200/70 p-1.5 flex items-center justify-center overflow-hidden min-h-[190px]">
                <img
                  src={currentImg}
                  alt={lang === 'en' ? item.titleEn : item.titleBn}
                  className="w-full h-auto max-h-[260px] object-contain rounded-lg transition-transform duration-300 group-hover:scale-[1.01]"
                  loading="lazy"
                />
                <div className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center pointer-events-none">
                  <div className="px-3 py-1.5 rounded-lg bg-white/95 text-gray-900 font-semibold text-xs flex items-center gap-1.5 shadow-md">
                    <Maximize2 className="w-3.5 h-3.5 text-blue-600" />
                    <span>{lang === 'en' ? 'Click to inspect' : 'পূর্ণাঙ্গ ভিউ'}</span>
                  </div>
                </div>
              </div>

              {/* Title & Description */}
              <div className="space-y-1.5 px-1">
                <div className="flex items-center justify-between">
                  <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded bg-blue-50 text-blue-600 border border-blue-200/60">
                    {item.category}
                  </span>
                  <div className="flex items-center gap-1 text-[11px] text-gray-400">
                    {showLight && <span className="hover:text-amber-500">Light</span>}
                    {showLight && showDark && <span>•</span>}
                    {showDark && <span className="hover:text-indigo-400">Dark</span>}
                  </div>
                </div>

                <h3 className="text-sm font-bold text-gray-900 group-hover:text-blue-600 transition-colors">
                  {lang === 'en' ? item.titleEn : item.titleBn}
                </h3>
                <p className="text-xs text-gray-500 line-clamp-2">
                  {lang === 'en' ? item.descriptionEn : item.descriptionBn}
                </p>
              </div>
            </div>
          );
        })}
      </div>

      {/* Lightbox Modal */}
      <ScreenshotLightbox
        item={selectedItem}
        items={filteredItems}
        onClose={() => setSelectedItem(null)}
        onSelect={(item) => setSelectedItem(item)}
      />
    </div>
  );
};
