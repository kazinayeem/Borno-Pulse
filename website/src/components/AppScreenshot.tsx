import React from 'react';
import { Maximize2 } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';

interface AppScreenshotProps {
  src: string;
  alt: string;
  className?: string;
  containerClassName?: string;
  onClick?: () => void;
  showExpandPrompt?: boolean;
  priority?: boolean;
}

export const AppScreenshot: React.FC<AppScreenshotProps> = ({
  src,
  alt,
  className = '',
  containerClassName = '',
  onClick,
  showExpandPrompt = true,
  priority = false,
}) => {
  const { lang } = useLanguage();

  return (
    <div
      onClick={onClick}
      className={`relative group overflow-hidden rounded-2xl bg-gray-950/5 border border-gray-200/80 flex items-center justify-center transition-all duration-300 ${
        onClick ? 'cursor-pointer hover:shadow-xl hover:border-blue-400/60' : ''
      } ${containerClassName}`}
    >
      {/* 
        CRITICAL: Use object-contain and max-w-full to guarantee that
        the entire macOS window, sidebar, and controls are 100% visible 
        without any cropping on left, right, top, or bottom.
      */}
      <img
        src={src}
        alt={alt}
        loading={priority ? 'eager' : 'lazy'}
        className={`w-full h-auto max-h-[82vh] object-contain transition-transform duration-300 group-hover:scale-[1.008] ${className}`}
      />

      {/* Click-to-Expand Hover Overlay */}
      {onClick && showExpandPrompt && (
        <div className="absolute inset-0 bg-black/25 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex items-center justify-center pointer-events-none">
          <div className="px-3.5 py-1.5 rounded-xl bg-white/95 text-gray-900 text-xs font-semibold shadow-lg flex items-center gap-1.5 backdrop-blur-xs">
            <Maximize2 className="w-3.5 h-3.5 text-blue-600" />
            <span>{lang === 'en' ? 'Click to expand' : 'পূর্ণাঙ্গ ভিউ দেখতে ক্লিক করুন'}</span>
          </div>
        </div>
      )}
    </div>
  );
};
