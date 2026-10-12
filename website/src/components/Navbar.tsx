import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useLanguage } from '../context/LanguageContext';
import { uiTranslations } from '../i18n/translations';
import { Download, Globe, Menu, X } from 'lucide-react';
import { GithubIcon } from './GithubIcon';


export const Navbar: React.FC = () => {
  const { lang, setLang } = useLanguage();
  const t = uiTranslations[lang];
  const location = useLocation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const toggleLanguage = () => {
    setLang(lang === 'en' ? 'bn' : 'en');
  };

  const navLinks = [
    { to: '/', label: t.navHome },
    { to: '/features', label: t.navFeatures },
    { to: '/screenshots', label: t.navScreenshots },
    { to: '/download', label: t.navDownload },
    { to: '/docs', label: t.navDocs },
    { to: '/contributing', label: t.navContributing },
    { to: '/privacy', label: t.navPrivacy },
    { to: '/faq', label: t.navFAQ },
  ];

  const isActive = (path: string) => {
    if (path === '/' && location.pathname === '/') return true;
    if (path !== '/' && location.pathname.startsWith(path)) return true;
    return false;
  };

  return (
    <header className="sticky top-0 z-50 w-full mac-glass border-b border-gray-200/80 transition-all">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
        {/* Brand Logo & Title */}
        <Link to="/" className="flex items-center gap-3 group">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-blue-600 to-indigo-500 p-0.5 shadow-sm shadow-blue-500/20 group-hover:scale-105 transition-transform flex items-center justify-center">
            <img src="/favicon.png" alt="Borno Pulse Icon" className="w-7 h-7 object-contain drop-shadow" />
          </div>
          <div className="flex flex-col">
            <span className="font-bold text-[17px] tracking-tight text-gray-900 flex items-center gap-1.5">
              Borno Pulse
              <span className="text-[10px] uppercase font-semibold px-1.5 py-0.5 bg-blue-50 text-blue-600 border border-blue-200/60 rounded">v1.3.0</span>
            </span>
            <span className="text-[11px] text-gray-500 font-medium -mt-1 hidden sm:inline">
              {lang === 'en' ? 'Smart Mac Utilities' : 'স্মার্ট ম্যাক ইউটিলিটি'}
            </span>
          </div>
        </Link>

        {/* Desktop Navigation Links */}
        <nav className="hidden lg:flex items-center gap-1">
          {navLinks.map((link) => (
            <Link
              key={link.to}
              to={link.to}
              className={`px-3 py-1.5 rounded-lg text-[13.5px] font-medium transition-colors ${
                isActive(link.to)
                  ? 'bg-gray-100 text-blue-600 font-semibold'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
              }`}
            >
              {link.label}
            </Link>
          ))}
        </nav>

        {/* Action Controls & Language Switcher */}
        <div className="hidden sm:flex items-center gap-2.5">
          {/* Language Switcher */}
          <button
            onClick={toggleLanguage}
            className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-gray-200 text-xs font-semibold text-gray-700 hover:bg-gray-50 transition-colors shadow-2xs"
            title="Switch Language / ভাষা পরিবর্তন করুন"
          >
            <Globe className="w-3.5 h-3.5 text-blue-600" />
            <span>{lang === 'en' ? 'বাংলা' : 'English'}</span>
          </button>

          {/* GitHub Repo */}
          <a
            href="https://github.com/kazinayeem/Borno-Pulse"
            target="_blank"
            rel="noopener noreferrer"
            className="p-1.5 rounded-lg border border-gray-200 text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors shadow-2xs"
            title="View GitHub Repository"
          >
            <GithubIcon className="w-4 h-4" />
          </a>

          {/* Download Button */}
          <Link
            to="/download"
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-[13px] font-semibold transition-all shadow-sm shadow-blue-500/20 active:scale-98"
          >
            <Download className="w-3.5 h-3.5" />
            <span>{t.downloadDMG}</span>
          </Link>
        </div>

        {/* Mobile Hamburger Button */}
        <div className="flex sm:hidden items-center gap-2">
          <button
            onClick={toggleLanguage}
            className="px-2 py-1 rounded border border-gray-200 text-xs font-semibold text-gray-700"
          >
            {lang === 'en' ? 'বাং' : 'EN'}
          </button>
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="p-2 text-gray-600 hover:text-gray-900"
          >
            {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
        </div>
      </div>

      {/* Mobile Drawer */}
      {mobileMenuOpen && (
        <div className="lg:hidden border-t border-gray-200 bg-white px-4 pt-3 pb-6 space-y-2 shadow-lg">
          {navLinks.map((link) => (
            <Link
              key={link.to}
              to={link.to}
              onClick={() => setMobileMenuOpen(false)}
              className={`block px-3 py-2 rounded-lg text-sm font-medium ${
                isActive(link.to) ? 'bg-blue-50 text-blue-600 font-semibold' : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              {link.label}
            </Link>
          ))}
          <div className="pt-2 border-t border-gray-100 flex gap-2">
            <Link
              to="/download"
              onClick={() => setMobileMenuOpen(false)}
              className="flex-1 text-center py-2 bg-blue-600 text-white text-sm font-semibold rounded-lg"
            >
              {t.downloadDMG}
            </Link>
            <a
              href="https://github.com/kazinayeem/Borno-Pulse"
              target="_blank"
              rel="noopener noreferrer"
              className="px-3 py-2 border border-gray-200 text-gray-700 rounded-lg flex items-center justify-center"
            >
              <GithubIcon className="w-5 h-5" />
            </a>
          </div>
        </div>
      )}
    </header>
  );
};
