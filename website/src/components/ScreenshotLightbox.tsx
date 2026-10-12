import React, { useEffect, useState } from 'react';
import type { ScreenshotItem } from '../types';

import { useLanguage } from '../context/LanguageContext';
import { X, ChevronLeft, ChevronRight, Sun, Moon } from 'lucide-react';

interface LightboxProps {
  item: ScreenshotItem | null;
  items: ScreenshotItem[];
  onClose: () => void;
  onSelect: (item: ScreenshotItem) => void;
}

export const ScreenshotLightbox: React.FC<LightboxProps> = ({ item, items, onClose, onSelect }) => {
  const { lang } = useLanguage();
  const [viewMode, setViewMode] = useState<'light' | 'dark'>('light');

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      } else if (e.key === 'ArrowRight' && item) {
        const idx = items.findIndex((i) => i.id === item.id);
        if (idx < items.length - 1) onSelect(items[idx + 1]);
      } else if (e.key === 'ArrowLeft' && item) {
        const idx = items.findIndex((i) => i.id === item.id);
        if (idx > 0) onSelect(items[idx - 1]);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [item, items, onClose, onSelect]);

  if (!item) return null;

  const currentIndex = items.findIndex((i) => i.id === item.id);
  const currentSrc = viewMode === 'light' ? item.lightSrc : item.darkSrc;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/85 backdrop-blur-md p-4 sm:p-6 transition-opacity">
      {/* Container Box */}
      <div className="relative w-full max-w-5xl bg-gray-900 border border-gray-800 rounded-2xl overflow-hidden shadow-2xl flex flex-col max-h-[92vh]">
        {/* Header Bar */}
        <div className="flex items-center justify-between px-5 py-3.5 border-b border-gray-800 bg-gray-950/70">
          <div className="flex items-center gap-3">
            <span className="text-xs uppercase font-bold tracking-wider px-2 py-0.5 rounded bg-blue-500/20 text-blue-400 border border-blue-500/30">
              {item.category}
            </span>
            <h3 className="text-sm font-semibold text-white truncate max-w-xs sm:max-w-md">
              {lang === 'en' ? item.titleEn : item.titleBn}
            </h3>
          </div>

          <div className="flex items-center gap-2">
            {/* Mode Switcher */}
            <div className="flex bg-gray-800 rounded-lg p-0.5 border border-gray-700">
              <button
                onClick={() => setViewMode('light')}
                className={`p-1.5 rounded-md text-xs font-medium flex items-center gap-1 transition-colors ${
                  viewMode === 'light' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-400 hover:text-white'
                }`}
                title="Light Mode"
              >
                <Sun className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Light</span>
              </button>
              <button
                onClick={() => setViewMode('dark')}
                className={`p-1.5 rounded-md text-xs font-medium flex items-center gap-1 transition-colors ${
                  viewMode === 'dark' ? 'bg-gray-700 text-white shadow-sm' : 'text-gray-400 hover:text-white'
                }`}
                title="Dark Mode"
              >
                <Moon className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Dark</span>
              </button>
            </div>

            {/* Close Button */}
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800 transition-colors"
              title="Close (Esc)"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Screenshot View Area */}
        <div className="relative flex-1 bg-black/60 flex items-center justify-center p-2 sm:p-6 overflow-auto min-h-[300px]">
          <img
            src={currentSrc}
            alt={lang === 'en' ? item.titleEn : item.titleBn}
            className="max-h-[70vh] w-auto object-contain rounded-lg shadow-lg border border-gray-800/80"
          />

          {/* Navigation Arrows */}
          {currentIndex > 0 && (
            <button
              onClick={() => onSelect(items[currentIndex - 1])}
              className="absolute left-4 top-1/2 -translate-y-1/2 p-2 rounded-full bg-gray-900/80 text-white border border-gray-700 hover:bg-blue-600 transition-colors shadow-lg"
              title="Previous Screenshot (Left Arrow)"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
          )}

          {currentIndex < items.length - 1 && (
            <button
              onClick={() => onSelect(items[currentIndex + 1])}
              className="absolute right-4 top-1/2 -translate-y-1/2 p-2 rounded-full bg-gray-900/80 text-white border border-gray-700 hover:bg-blue-600 transition-colors shadow-lg"
              title="Next Screenshot (Right Arrow)"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          )}
        </div>

        {/* Caption Bar */}
        <div className="px-5 py-3 border-t border-gray-800 bg-gray-950/80 flex items-center justify-between text-xs text-gray-400">
          <p className="line-clamp-1">{lang === 'en' ? item.descriptionEn : item.descriptionBn}</p>
          <span className="font-mono text-gray-500 shrink-0 ml-4">
            {currentIndex + 1} / {items.length}
          </span>
        </div>
      </div>
    </div>
  );
};
