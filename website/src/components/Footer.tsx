import React from 'react';
import { Link } from 'react-router-dom';
import { useLanguage } from '../context/LanguageContext';
import { uiTranslations } from '../i18n/translations';
import { Heart, Globe, Shield, Terminal, Download } from 'lucide-react';
import { GithubIcon } from './GithubIcon';


export const Footer: React.FC = () => {
  const { lang } = useLanguage();
  const t = uiTranslations[lang];

  return (
    <footer className="bg-gray-900 text-gray-300 border-t border-gray-800 transition-colors">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-14">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-10">
          {/* Brand & Mission */}
          <div className="space-y-4">
            <div className="flex items-center gap-2.5">
              <img src="/favicon.png" alt="Borno Pulse Logo" className="w-7 h-7" />
              <span className="text-xl font-bold text-white tracking-tight">Borno Pulse</span>
            </div>
            <p className="text-sm text-gray-400 leading-relaxed">
              {lang === 'en'
                ? 'A production-grade, privacy-first macOS utility suite engineered in native Swift 6 and SwiftUI. Completely free and open-source.'
                : 'সুইফট ৬ এবং সুইফটইউআই দিয়ে তৈরি নেটিভ ম্যাকওএস সুপার ইউটিলিটি স্যুট। ১০০% ফ্রি, সুরক্ষিত এবং সম্পূর্ণ ওপেন সোর্স।'}
            </p>
            <div className="flex items-center gap-3 pt-1">
              <a
                href="https://github.com/kazinayeem/Borno-Pulse"
                target="_blank"
                rel="noopener noreferrer"
                className="w-8 h-8 rounded-lg bg-gray-800 flex items-center justify-center text-gray-400 hover:text-white hover:bg-gray-700 transition-colors"
                title="GitHub Repository"
              >
                <GithubIcon className="w-4 h-4" />
              </a>
              <a
                href="https://bornosoft.bd"
                target="_blank"
                rel="noopener noreferrer"
                className="w-8 h-8 rounded-lg bg-gray-800 flex items-center justify-center text-gray-400 hover:text-white hover:bg-gray-700 transition-colors"
                title="BornoSoft"
              >
                <Globe className="w-4 h-4" />
              </a>
            </div>
          </div>

          {/* Quick Links */}
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-4">
              {lang === 'en' ? 'Product & Navigation' : 'ন্যাভিগেশন ও ফিচার'}
            </h4>
            <ul className="space-y-2.5 text-sm">
              <li><Link to="/features" className="hover:text-white transition-colors">{t.navFeatures}</Link></li>
              <li><Link to="/screenshots" className="hover:text-white transition-colors">{t.navScreenshots}</Link></li>
              <li><Link to="/download" className="hover:text-white transition-colors">{t.navDownload}</Link></li>
              <li><Link to="/docs" className="hover:text-white transition-colors">{t.navDocs}</Link></li>
              <li><Link to="/faq" className="hover:text-white transition-colors">{t.navFAQ}</Link></li>
            </ul>
          </div>

          {/* Open Source & Community */}
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-4">
              {lang === 'en' ? 'Open Source & Docs' : 'ওপেন সোর্স ও ডকুমেন্ট'}
            </h4>
            <ul className="space-y-2.5 text-sm">
              <li><Link to="/contributing" className="hover:text-white transition-colors">{t.navContributing}</Link></li>
              <li><Link to="/privacy" className="hover:text-white transition-colors">{t.navPrivacy}</Link></li>
              <li>
                <a
                  href="https://github.com/kazinayeem/Borno-Pulse/blob/main/LICENSE"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-white transition-colors flex items-center gap-1.5"
                >
                  <Shield className="w-3.5 h-3.5 text-emerald-400" />
                  MIT License
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/kazinayeem/Borno-Pulse/releases"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-white transition-colors flex items-center gap-1.5"
                >
                  <Download className="w-3.5 h-3.5 text-blue-400" />
                  Release Artifacts
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/kazinayeem/Borno-Pulse/issues"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-white transition-colors flex items-center gap-1.5"
                >
                  <Terminal className="w-3.5 h-3.5 text-purple-400" />
                  Report Issue / Bug
                </a>
              </li>
            </ul>
          </div>

          {/* Founder & Attribution */}
          <div className="space-y-3">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-4">
              {lang === 'en' ? 'Crafted by BornoSoft' : 'নির্মাতা ও স্বীকৃতি'}
            </h4>
            <div className="p-3.5 rounded-xl bg-gray-800/80 border border-gray-700/60 flex items-start gap-3">
              <img
                src="/developer_avatar.png"
                onError={(e) => {
                  (e.currentTarget as HTMLImageElement).src = 'https://avatars.githubusercontent.com/u/85398213?v=4';
                }}
                alt="Mohammad Ali Nayeem"
                className="w-10 h-10 rounded-full border border-blue-500/60 object-cover shadow-sm shrink-0"
              />
              <div className="space-y-0.5">
                <div className="text-sm font-semibold text-white">Mohammad Ali Nayeem</div>
                <div className="text-xs text-gray-400">Software Engineer</div>
                <div className="text-[11px] text-blue-400 font-medium">Founder of BornoSoft</div>
              </div>
            </div>
            <div className="text-xs text-gray-400 pt-1">
              <a href="https://bornosoft.bd" target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:underline">
                https://bornosoft.bd
              </a>
            </div>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="mt-12 pt-8 border-t border-gray-800 flex flex-col sm:flex-row items-center justify-between text-xs text-gray-500 gap-4">
          <p>© 2026 BornoSoft. Free & Open Source under the MIT License.</p>
          <p className="flex items-center gap-1">
            Engineered with <Heart className="w-3.5 h-3.5 text-red-500 fill-red-500 inline" /> for the macOS developer community
          </p>
        </div>
      </div>
    </footer>
  );
};
