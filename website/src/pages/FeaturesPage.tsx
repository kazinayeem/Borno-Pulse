import React, { useState } from 'react';
import { useLanguage } from '../context/LanguageContext';
import { featuresList } from '../data/featuresData';
import { ScreenshotLightbox } from '../components/ScreenshotLightbox';
import type { ScreenshotItem } from '../types';

import { screenshotsList } from '../data/screenshotsData';
import {
  Sparkles,
  Laptop,
  Network,
  FileText,
  Activity,
  Sliders,
  CheckCircle2,
  Sun,
  Moon,
  Search,
} from 'lucide-react';

export const FeaturesPage: React.FC = () => {
  const { lang } = useLanguage();
  const [activeCategory, setActiveCategory] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [selectedLightboxItem, setSelectedLightboxItem] = useState<ScreenshotItem | null>(null);
  const [viewModes, setViewModes] = useState<Record<string, 'light' | 'dark'>>({});

  const categories = [
    { id: 'all', label: lang === 'en' ? 'All Features (25)' : 'সব ফিচার (২৫)' },
    { id: 'system', label: lang === 'en' ? 'System & Cleaner' : 'সিস্টেম ও ক্লিনার' },
    { id: 'monitoring', label: lang === 'en' ? 'Hardware Telemetry' : 'হার্ডওয়্যার টেলিমেট্রি' },
    { id: 'developer', label: lang === 'en' ? 'Developer Tools' : 'ডেভেলপার টুলস' },
    { id: 'productivity', label: lang === 'en' ? 'Files & Widget' : 'ফাইল ও উইজেট' },
  ];

  const filteredFeatures = featuresList.filter((feat) => {
    const matchesCat = activeCategory === 'all' || feat.category === activeCategory;
    const q = searchQuery.toLowerCase();
    const matchesSearch =
      feat.titleEn.toLowerCase().includes(q) ||
      feat.titleBn.toLowerCase().includes(q) ||
      feat.descriptionEn.toLowerCase().includes(q) ||
      feat.descriptionBn.toLowerCase().includes(q);
    return matchesCat && matchesSearch;
  });

  const getIcon = (name: string) => {
    switch (name) {
      case 'Sparkles': return <Sparkles className="w-5 h-5" />;
      case 'Laptop': return <Laptop className="w-5 h-5" />;
      case 'Network': return <Network className="w-5 h-5" />;
      case 'FileText': return <FileText className="w-5 h-5" />;
      case 'Activity': return <Activity className="w-5 h-5" />;
      case 'Sliders': return <Sliders className="w-5 h-5" />;
      default: return <Activity className="w-5 h-5" />;
    }
  };

  const toggleFeatureMode = (id: string) => {
    setViewModes((prev) => ({
      ...prev,
      [id]: prev[id] === 'dark' ? 'light' : 'dark',
    }));
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-12">
      {/* Page Header */}
      <div className="text-center max-w-3xl mx-auto space-y-4">
        <span className="text-xs font-bold uppercase tracking-widest text-blue-600">
          {lang === 'en' ? 'Full Module Inventory' : 'পূর্ণাঙ্গ ফিচার ও মডিউল পরিচিতি'}
        </span>
        <h1 className="text-4xl sm:text-5xl font-extrabold text-gray-950 tracking-tight">
          {lang === 'en' ? 'Engineered for Power Users & Developers' : 'পাওয়ার ইউজার ও ডেভেলপারদের জন্য নির্মিত'}
        </h1>
        <p className="text-base text-gray-600 leading-relaxed">
          {lang === 'en'
            ? 'Borno Pulse packs 25 deep native utilities into a unified, privacy-first interface. Every feature runs 100% locally on Apple Silicon and Intel Macs with zero cloud dependencies.'
            : '২৫টি নেটিভ ম্যাক ইউটিলিটি একটি সমন্বিত প্ল্যাটফর্মে। সম্পূর্ণ অফলাইনে অ্যাপল সিলিকন ও ইন্টেল প্রসেসরের সর্বোচ্চ গতিতে পরিচালিত।'}
        </p>
      </div>

      {/* Controls: Filter Tabs & Search */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 border-b border-gray-200 pb-6">
        <div className="flex flex-wrap items-center gap-1.5 w-full sm:w-auto">
          {categories.map((cat) => (
            <button
              key={cat.id}
              onClick={() => setActiveCategory(cat.id)}
              className={`px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
                activeCategory === cat.id
                  ? 'bg-blue-600 text-white shadow-2xs'
                  : 'bg-white border border-gray-200 text-gray-700 hover:bg-gray-50'
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>

        <div className="relative w-full sm:w-72">
          <Search className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder={lang === 'en' ? 'Filter features...' : 'ফিচার সার্চ করুন...'}
            className="w-full pl-9 pr-4 py-1.5 text-xs rounded-lg border border-gray-200 bg-white focus:outline-hidden focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
          />
        </div>
      </div>

      {/* Features List */}
      <div className="space-y-16">
        {filteredFeatures.map((feat, index) => {
          const mode = viewModes[feat.id] || 'light';
          const imgSrc = mode === 'light' ? feat.screenshotLight : feat.screenshotDark;

          return (
            <div
              key={feat.id}
              className={`grid grid-cols-1 lg:grid-cols-2 gap-10 items-center p-6 sm:p-8 rounded-3xl bg-white border border-gray-200/80 shadow-xs ${
                index % 2 === 1 ? 'lg:flex-row-reverse' : ''
              }`}
            >
              {/* Left Column: Details */}
              <div className={`space-y-6 ${index % 2 === 1 ? 'lg:order-2' : ''}`}>
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center font-bold">
                    {getIcon(feat.iconName)}
                  </div>
                  <div>
                    <h3 className="text-2xl font-bold text-gray-950">
                      {lang === 'en' ? feat.titleEn : feat.titleBn}
                    </h3>
                    <p className="text-xs font-semibold text-blue-600">
                      {lang === 'en' ? feat.taglineEn : feat.taglineBn}
                    </p>
                  </div>
                </div>

                <p className="text-sm text-gray-600 leading-relaxed">
                  {lang === 'en' ? feat.descriptionEn : feat.descriptionBn}
                </p>

                <div className="space-y-2.5">
                  <span className="text-xs font-bold uppercase tracking-wider text-gray-400">
                    {lang === 'en' ? 'Core Capabilities' : 'মূল সুবিধাসমূহ'}
                  </span>
                  <ul className="space-y-2 text-xs sm:text-sm text-gray-700">
                    {(lang === 'en' ? feat.highlightsEn : feat.highlightsBn).map((hl, i) => (
                      <li key={i} className="flex items-start gap-2">
                        <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
                        <span>{hl}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              {/* Right Column: Screenshot Box */}
              <div className={`space-y-2 ${index % 2 === 1 ? 'lg:order-1' : ''}`}>
                <div className="flex items-center justify-between text-xs text-gray-500 px-1">
                  <span className="font-medium">
                    {lang === 'en' ? 'Authentic App Screen' : 'আসল অ্যাপ স্ক্রিনশট'}
                  </span>
                  <button
                    onClick={() => toggleFeatureMode(feat.id)}
                    className="flex items-center gap-1 px-2 py-0.5 rounded border border-gray-200 text-xs text-gray-600 hover:bg-gray-50 transition-colors"
                  >
                    {mode === 'light' ? <Moon className="w-3 h-3" /> : <Sun className="w-3 h-3" />}
                    <span>{mode === 'light' ? 'Dark' : 'Light'}</span>
                  </button>
                </div>

                <div
                  onClick={() => {
                    const found = screenshotsList.find((s) => s.id === feat.id);
                    if (found) setSelectedLightboxItem(found);
                  }}
                  className="cursor-pointer group rounded-2xl bg-gray-100 border border-gray-200 overflow-hidden shadow-md hover:shadow-xl transition-all"
                >
                  <img
                    src={imgSrc}
                    alt={lang === 'en' ? feat.titleEn : feat.titleBn}
                    className="w-full object-cover group-hover:scale-[1.01] transition-transform"
                  />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Lightbox for screenshots */}
      <ScreenshotLightbox
        item={selectedLightboxItem}
        items={screenshotsList}
        onClose={() => setSelectedLightboxItem(null)}
        onSelect={(item) => setSelectedLightboxItem(item)}
      />
    </div>
  );
};
