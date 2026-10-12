import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { useLanguage } from '../context/LanguageContext';
import { uiTranslations } from '../i18n/translations';
import { screenshotsList } from '../data/screenshotsData';
import { ScreenshotLightbox } from '../components/ScreenshotLightbox';
import type { ScreenshotItem } from '../types';
import { GithubIcon } from '../components/GithubIcon';
import {
  Download,
  Cpu,
  Laptop,
  Sparkles,
  ShieldCheck,
  ArrowRight,
  Sun,
  Moon,
  ChevronRight,
  CheckCircle2,
} from 'lucide-react';


export const HomePage: React.FC = () => {
  const { lang } = useLanguage();
  const t = uiTranslations[lang];

  // Hero Mac Window interactive tab
  const heroTabs = [
    { id: 'overview', label: lang === 'en' ? 'Overview' : 'ওভারভিউ', src: '/screenshots/light/overview.png', darkSrc: '/screenshots/dark/overview.png' },
    { id: 'cleaner', label: lang === 'en' ? 'System Cleaner' : 'ক্লিনার', src: '/screenshots/light/cleaner.png', darkSrc: '/screenshots/dark/cleaner.png' },
    { id: 'clamshell_mode', label: lang === 'en' ? 'Clamshell Mode' : 'ক্ল্যামশেল', src: '/screenshots/light/clamshell_mode.png', darkSrc: '/screenshots/dark/clamshell_mode.png' },
    { id: 'port_manager', label: lang === 'en' ? 'Port Manager' : 'পোর্ট অডিটর', src: '/screenshots/light/port_manager.png', darkSrc: '/screenshots/dark/port_manager.png' },
    { id: 'battery', label: lang === 'en' ? 'Battery Wattage' : 'ব্যাটারি', src: '/screenshots/light/battery.png', darkSrc: '/screenshots/dark/battery.png' },
    { id: 'pdf_studio', label: lang === 'en' ? 'PDF Studio' : 'পিডিএফ স্টুডিও', src: '/screenshots/light/pdf_studio.png', darkSrc: '/screenshots/dark/pdf_studio.png' },
  ];

  const [activeHeroTab, setActiveHeroTab] = useState(heroTabs[0]);
  const [heroMode, setHeroMode] = useState<'light' | 'dark'>('light');
  const [selectedLightboxItem, setSelectedLightboxItem] = useState<ScreenshotItem | null>(null);

  return (
    <div className="space-y-24 pb-20">
      {/* 1. HERO SECTION */}
      <section className="relative pt-12 sm:pt-20 pb-8 overflow-hidden">
        {/* Subtle radial ambient background glow */}
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[350px] bg-gradient-to-tr from-blue-400/15 via-indigo-400/10 to-teal-400/10 blur-3xl pointer-events-none -z-10 rounded-full" />

        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 text-center space-y-6">
          {/* Release & Platform Badges */}
          <div className="inline-flex flex-wrap items-center justify-center gap-2 px-3 py-1.5 rounded-full bg-white/90 border border-gray-200/80 shadow-xs text-xs font-medium text-gray-700">
            <span className="flex items-center gap-1 text-blue-600 font-semibold">
              <span className="w-2 h-2 rounded-full bg-blue-600 animate-pulse" />
              {t.versionBadge}
            </span>
            <span className="text-gray-300">•</span>
            <span>{t.universalBadge}</span>
            <span className="text-gray-300">•</span>
            <span className="text-emerald-600 font-medium">{t.privacyBadge}</span>
          </div>

          {/* Main Title & Tagline */}
          <h1 className="text-4xl sm:text-6xl font-extrabold text-gray-950 tracking-tight leading-[1.12]">
            {lang === 'en' ? (
              <>
                Smart Mac Utilities & <br className="hidden sm:inline" />
                <span className="bg-gradient-to-r from-blue-600 via-indigo-600 to-sky-500 bg-clip-text text-transparent">
                  System Telemetry Suite
                </span>
              </>
            ) : (
              <>
                ম্যাকের স্মার্ট ইউটিলিটি ও <br className="hidden sm:inline" />
                <span className="bg-gradient-to-r from-blue-600 via-indigo-600 to-sky-500 bg-clip-text text-transparent">
                  সিস্টেম টেলিমেট্রি স্যুট
                </span>
              </>
            )}
          </h1>

          {/* Subtitle */}
          <p className="max-w-2xl mx-auto text-base sm:text-lg text-gray-600 leading-relaxed font-normal">
            {t.heroSubtitle}
          </p>

          {/* Call to Action Buttons */}
          <div className="pt-2 flex flex-wrap items-center justify-center gap-3.5">
            <Link
              to="/download"
              className="inline-flex items-center gap-2.5 px-6 py-3 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-semibold text-sm sm:text-base shadow-md shadow-blue-500/25 active:scale-98 transition-all"
            >
              <Download className="w-5 h-5" />
              <span>{t.downloadDMG}</span>
              <span className="text-xs px-1.5 py-0.5 rounded bg-blue-500 text-white font-mono">18 MB</span>
            </Link>

            <a
              href="https://github.com/kazinayeem/Borno-Pulse"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-white hover:bg-gray-50 border border-gray-200/90 text-gray-800 font-semibold text-sm sm:text-base shadow-xs transition-colors"
            >
              <GithubIcon className="w-5 h-5" />
              <span>{t.sourceCode}</span>
            </a>

            <Link
              to="/screenshots"
              className="inline-flex items-center gap-1.5 px-4 py-3 rounded-xl text-gray-600 hover:text-gray-900 text-sm font-medium transition-colors"
            >
              <span>{t.viewGallery}</span>
              <ArrowRight className="w-4 h-4" />
            </Link>
          </div>

          {/* Interactive Mac Window Demo with Real Screenshots */}
          <div className="pt-8 max-w-5xl mx-auto">
            {/* macOS Window Shell */}
            <div className="rounded-2xl bg-white border border-gray-200/90 shadow-2xl mac-shadow overflow-hidden text-left transition-all">
              {/* Window Titlebar */}
              <div className="flex items-center justify-between px-4 py-3 bg-gray-100/90 border-b border-gray-200/80">
                <div className="flex items-center gap-2">
                  <span className="w-3 h-3 rounded-full bg-[#FF5F56] border border-[#E0443E]/60 inline-block" />
                  <span className="w-3 h-3 rounded-full bg-[#FFBD2E] border border-[#DEA123]/60 inline-block" />
                  <span className="w-3 h-3 rounded-full bg-[#27C93F] border border-[#1AAB29]/60 inline-block" />
                  <span className="text-xs font-semibold text-gray-600 ml-2">Borno Pulse — {activeHeroTab.label}</span>
                </div>

                {/* Light/Dark Toggle */}
                <div className="flex items-center gap-1 bg-gray-200/80 rounded-lg p-0.5">
                  <button
                    onClick={() => setHeroMode('light')}
                    className={`px-2 py-0.5 rounded text-[11px] font-medium flex items-center gap-1 transition-colors ${
                      heroMode === 'light' ? 'bg-white text-gray-900 shadow-2xs' : 'text-gray-500 hover:text-gray-900'
                    }`}
                  >
                    <Sun className="w-3 h-3" />
                    <span>Light</span>
                  </button>
                  <button
                    onClick={() => setHeroMode('dark')}
                    className={`px-2 py-0.5 rounded text-[11px] font-medium flex items-center gap-1 transition-colors ${
                      heroMode === 'dark' ? 'bg-gray-800 text-white shadow-2xs' : 'text-gray-500 hover:text-gray-900'
                    }`}
                  >
                    <Moon className="w-3 h-3" />
                    <span>Dark</span>
                  </button>
                </div>
              </div>

              {/* Module Tab Selector */}
              <div className="flex items-center gap-1.5 px-4 py-2 bg-gray-50 border-b border-gray-200/60 overflow-x-auto text-xs font-medium">
                {heroTabs.map((tab) => (
                  <button
                    key={tab.id}
                    onClick={() => setActiveHeroTab(tab)}
                    className={`px-3 py-1.5 rounded-lg whitespace-nowrap transition-colors ${
                      activeHeroTab.id === tab.id
                        ? 'bg-blue-600 text-white font-semibold shadow-2xs'
                        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
                    }`}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>

              {/* Window Body Image */}
              <div className="relative bg-[#1E1E24] p-1 sm:p-2 aspect-[16/10] overflow-hidden flex items-center justify-center">
                <img
                  src={heroMode === 'light' ? activeHeroTab.src : activeHeroTab.darkSrc}
                  alt={`Borno Pulse ${activeHeroTab.label}`}
                  className="w-full h-full object-contain object-top rounded-lg"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 2. CORE VALUE PILLARS */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <div className="p-6 rounded-2xl bg-white border border-gray-200/80 shadow-xs space-y-3">
            <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center font-bold">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <h3 className="font-bold text-gray-900 text-base">
              {lang === 'en' ? '100% Offline & Local' : '১০০% অফলাইন ও লোকাল'}
            </h3>
            <p className="text-sm text-gray-600 leading-relaxed">
              {lang === 'en'
                ? 'Zero telemetry, zero trackers, and zero backend databases. Your clipboard, metrics, and files never leave your Mac.'
                : 'কোনো দূরবর্তী সার্ভার বা ট্র্যাকিং নেই। আপনার ফাইল, মেট্রিক্স ও ক্লিপবোর্ড আপনার নিজের ম্যাকের ভেতরই সংরক্ষিত থাকে।'}
            </p>
          </div>

          <div className="p-6 rounded-2xl bg-white border border-gray-200/80 shadow-xs space-y-3">
            <div className="w-10 h-10 rounded-xl bg-indigo-50 text-indigo-600 flex items-center justify-center font-bold">
              <Cpu className="w-5 h-5" />
            </div>
            <h3 className="font-bold text-gray-900 text-base">
              {lang === 'en' ? 'Swift 6 Strict Concurrency' : 'সুইফট ৬ নেটিভ পারফরম্যান্স'}
            </h3>
            <p className="text-sm text-gray-600 leading-relaxed">
              {lang === 'en'
                ? 'Native Mach kernel, IOKit, Metal compute pipelines, and CoreGraphics APIs compiled for Apple Silicon and Intel.'
                : 'অ্যাপল কার্নেল, আইওকিট এবং মেটাল গ্রাফিক্স এপিআই দিয়ে নির্মিত উচ্চ ক্ষমতাসম্পন্ন নেটিভ আর্কিটেকচার।'}
            </p>
          </div>

          <div className="p-6 rounded-2xl bg-white border border-gray-200/80 shadow-xs space-y-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center font-bold">
              <Sparkles className="w-5 h-5" />
            </div>
            <h3 className="font-bold text-gray-900 text-base">
              {lang === 'en' ? 'Safe Multi-Tier Cleaning' : 'নিরাপদ সিস্টেম ক্লিনার'}
            </h3>
            <p className="text-sm text-gray-600 leading-relaxed">
              {lang === 'en'
                ? 'Reclaim dozens of GBs from Xcode caches, logs, and nested node_modules with zero risk to source code.'
                : 'সোর্স কোড ও প্যাকেজ অপরিবর্তিত রেখে অপ্রয়োজনীয় node_modules এবং ক্যাশ মুছে গিগাবাইট জায়গা বাঁচান।'}
            </p>
          </div>

          <div className="p-6 rounded-2xl bg-white border border-gray-200/80 shadow-xs space-y-3">
            <div className="w-10 h-10 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center font-bold">
              <Laptop className="w-5 h-5" />
            </div>
            <h3 className="font-bold text-gray-900 text-base">
              {lang === 'en' ? 'Clamshell Sleep Prevention' : 'ক্ল্যামশেল মোড (ঢাকনা বন্ধ)'}
            </h3>
            <p className="text-sm text-gray-600 leading-relaxed">
              {lang === 'en'
                ? 'Run background scripts, Docker, and dev servers with the laptop lid closed via native IOKit power assertions.'
                : 'ঢাকনা বন্ধ থাকা সত্ত্বেও ডকার, লোকাল সার্ভার এবং ভারি স্ক্রিপ্ট অনায়াসে সচল রাখুন।'}
            </p>
          </div>
        </div>
      </section>

      {/* 3. SHOWCASE: ADVANCED SYSTEM & NODE CLEANER */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          <div className="space-y-6">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-lg bg-emerald-50 text-emerald-700 text-xs font-semibold border border-emerald-200/60">
              <Sparkles className="w-4 h-4" />
              <span>{lang === 'en' ? 'Storage Reclaimer' : 'স্টোরেজ রিক্লেমার'}</span>
            </div>
            <h2 className="text-3xl sm:text-4xl font-bold text-gray-950 tracking-tight leading-tight">
              {t.cleanerTitle}
            </h2>
            <p className="text-gray-600 leading-relaxed">
              {t.cleanerDesc}
            </p>
            <ul className="space-y-3 text-sm text-gray-700">
              <li className="flex items-center gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>{lang === 'en' ? 'Deep recursive project scan detecting npm, pnpm, yarn, and bun workspaces' : 'npm, pnpm, yarn এবং bun প্রজেক্টের ডিপ রিকার্সিভ স্ক্যানার'}</span>
              </li>
              <li className="flex items-center gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>{lang === 'en' ? 'Simulation dry-run report to inspect exact reclaimable size before deletion' : 'মুছে ফেলার আগেই কতটুকু জায়গা খালি হবে তা দেখার প্রিভিউ'}</span>
              </li>
              <li className="flex items-center gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>{lang === 'en' ? 'Strict safety invariants: parent folders and package.json are never touched' : 'কঠোর নিরাপত্তা: মূল সোর্স ফাইল ও package.json সর্বদা অক্ষত থাকে'}</span>
              </li>
            </ul>
            <div className="pt-2">
              <Link
                to="/features"
                className="inline-flex items-center gap-1.5 text-blue-600 hover:text-blue-700 font-semibold text-sm"
              >
                <span>{lang === 'en' ? 'Learn more about Cleaner Architecture' : 'ক্লিনার আর্কিটেকচার সম্পর্কে আরও জানুন'}</span>
                <ChevronRight className="w-4 h-4" />
              </Link>
            </div>
          </div>

          <div
            onClick={() => setSelectedLightboxItem(screenshotsList.find((s) => s.id === 'cleaner') || null)}
            className="group cursor-pointer rounded-2xl bg-white border border-gray-200/90 p-2 shadow-xl hover:shadow-2xl transition-all"
          >
            <img
              src="/screenshots/light/cleaner.png"
              alt="System Cleaner Screen"
              className="rounded-xl w-full object-cover group-hover:scale-[1.01] transition-transform"
            />
            <div className="p-3 text-center text-xs text-gray-500 font-medium">
              {lang === 'en' ? 'Click to inspect high-resolution preview' : 'হাই-রেজোলিউশন প্রিভিউ দেখতে ক্লিক করুন'}
            </div>
          </div>
        </div>
      </section>

      {/* 4. SHOWCASE: CLAMSHELL MODE & LID-CLOSED OPERATION */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          <div
            onClick={() => setSelectedLightboxItem(screenshotsList.find((s) => s.id === 'clamshell_mode') || null)}
            className="group cursor-pointer rounded-2xl bg-white border border-gray-200/90 p-2 shadow-xl hover:shadow-2xl transition-all order-2 lg:order-1"
          >
            <img
              src="/screenshots/light/clamshell_mode.png"
              alt="Clamshell Mode Screen"
              className="rounded-xl w-full object-cover group-hover:scale-[1.01] transition-transform"
            />
            <div className="p-3 text-center text-xs text-gray-500 font-medium">
              {lang === 'en' ? 'Real Clamshell Mode screen capture' : 'ক্ল্যামশেল মোডের আসল স্ক্রিনশট'}
            </div>
          </div>

          <div className="space-y-6 order-1 lg:order-2">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-lg bg-blue-50 text-blue-700 text-xs font-semibold border border-blue-200/60">
              <Laptop className="w-4 h-4" />
              <span>{lang === 'en' ? 'Power & Workload Assertions' : 'পাওয়ার ও স্লিপ অ্যাসার্শন'}</span>
            </div>
            <h2 className="text-3xl sm:text-4xl font-bold text-gray-950 tracking-tight leading-tight">
              {t.clamshellTitle}
            </h2>
            <p className="text-gray-600 leading-relaxed">
              {t.clamshellDesc}
            </p>
            <ul className="space-y-3 text-sm text-gray-700">
              <li className="flex items-center gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-blue-600 shrink-0" />
                <span>{lang === 'en' ? 'Live hardware checklist: AC adapter, battery percentage, external display' : 'লাইভ হার্ডওয়্যার অডিট: চার্জার সংযোগ, ব্যাটারি ও ডিসপ্লে স্টেট'}</span>
              </li>
              <li className="flex items-center gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-blue-600 shrink-0" />
                <span>{lang === 'en' ? 'Diagnostic monitoring of active listening sockets and Docker container status' : 'ডকার ও লোকাল লিসেনিং পোর্টের সক্রিয়তা পর্যবেক্ষণ'}</span>
              </li>
              <li className="flex items-center gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-blue-600 shrink-0" />
                <span>{lang === 'en' ? 'Countdown timer presets (1h, 2h, 3h, custom or continuous until stopped)' : 'টাইমার প্রিসেট (১ঘণ্টা, ২ঘণ্টা, ৩ঘণ্টা বা বন্ধ না করা পর্যন্ত)'}</span>
              </li>
            </ul>
          </div>
        </div>
      </section>

      {/* 5. SHOWCASE: MENU BAR UTILITY WIDGET */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="p-8 sm:p-12 rounded-3xl bg-gradient-to-b from-gray-900 to-gray-950 text-white border border-gray-800 shadow-2xl space-y-10">
          <div className="max-w-2xl space-y-3">
            <span className="text-xs font-bold uppercase tracking-widest text-blue-400">
              {lang === 'en' ? 'Instant Access Everywhere' : 'স্ট্যাটাস বার থেকে তাৎক্ষণিক নিয়ন্ত্রণ'}
            </span>
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight text-white">
              {t.quickActionsWidget}
            </h2>
            <p className="text-gray-400 text-sm sm:text-base leading-relaxed">
              {t.widgetDesc}
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            <div
              onClick={() => setSelectedLightboxItem(screenshotsList.find((s) => s.id === 'widget_actions') || null)}
              className="cursor-pointer group rounded-xl bg-gray-800/80 p-2 border border-gray-700/80 hover:border-blue-500/80 transition-all"
            >
              <img
                src="/screenshots/widget/dark-actions.png"
                alt="21-Action Grid"
                className="w-full rounded-lg object-contain"
              />
              <div className="p-2 text-center text-xs text-gray-400 font-medium group-hover:text-white">
                {lang === 'en' ? '21 Quick Actions Grid' : '২১টি কুইক অ্যাকশন গ্রিড'}
              </div>
            </div>

            <div
              onClick={() => setSelectedLightboxItem(screenshotsList.find((s) => s.id === 'widget_battery') || null)}
              className="cursor-pointer group rounded-xl bg-gray-800/80 p-2 border border-gray-700/80 hover:border-blue-500/80 transition-all"
            >
              <img
                src="/screenshots/widget/dark-battery.png"
                alt="Battery Wattage & Drain"
                className="w-full rounded-lg object-contain"
              />
              <div className="p-2 text-center text-xs text-gray-400 font-medium group-hover:text-white">
                {lang === 'en' ? 'Battery Wattage & Drain' : 'ব্যাটারি ওয়াটেজ ও ক্ষয়'}
              </div>
            </div>

            <div
              onClick={() => setSelectedLightboxItem(screenshotsList.find((s) => s.id === 'widget_hardware') || null)}
              className="cursor-pointer group rounded-xl bg-gray-800/80 p-2 border border-gray-700/80 hover:border-blue-500/80 transition-all"
            >
              <img
                src="/screenshots/widget/dark-hardware.png"
                alt="Hardware Load Snapshot"
                className="w-full rounded-lg object-contain"
              />
              <div className="p-2 text-center text-xs text-gray-400 font-medium group-hover:text-white">
                {lang === 'en' ? 'Hardware Load Snapshot' : 'হার্ডওয়্যার লোড স্ন্যাপশট'}
              </div>
            </div>

            <div className="rounded-xl bg-gray-800/40 p-5 border border-gray-700/50 flex flex-col justify-between">
              <div className="space-y-3">
                <span className="text-xs font-semibold text-blue-400 uppercase tracking-wider">
                  {lang === 'en' ? 'Menu Bar Tokens' : 'স্ট্যাটাস টোকেন'}
                </span>
                <h4 className="text-base font-bold text-white">
                  {lang === 'en' ? 'Custom Status Item Metrics' : 'কাস্টম স্ট্যাটাস আইটেম মেট্রিক্স'}
                </h4>
                <p className="text-xs text-gray-400 leading-relaxed">
                  {lang === 'en'
                    ? 'Pin live CPU %, GPU %, RAM pressure, battery wattage, or temperature right into your macOS status bar.'
                    : 'সিপিইউ %, মেমোরি চাপ, ব্যাটারি ওয়াটেজ ও তাপমাত্রা সরাসরি আপনার স্ট্যাটাস বারে পিন করুন।'}
                </p>
              </div>
              <Link
                to="/features"
                className="mt-4 text-xs font-semibold text-blue-400 hover:text-blue-300 flex items-center gap-1"
              >
                <span>{lang === 'en' ? 'View all widget capabilities' : 'সব উইজেট ফিচার দেখুন'}</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* 6. REAL SCREENSHOT MINI-GALLERY */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">
        <div className="flex flex-col sm:flex-row items-start sm:items-end justify-between gap-4">
          <div className="space-y-2">
            <span className="text-xs font-bold uppercase tracking-wider text-blue-600">
              {lang === 'en' ? 'Authentic App Experience' : 'আসল অ্যাপের স্ক্রিনশট গ্যালারি'}
            </span>
            <h2 className="text-3xl font-bold text-gray-950 tracking-tight">
              {lang === 'en' ? 'Real Screenshots from Borno Pulse' : 'Borno Pulse অ্যাপের মূল স্ক্রিনশটসমূহ'}
            </h2>
            <p className="text-sm text-gray-600">
              {lang === 'en'
                ? 'Captured programmatically from the running native macOS application. No mockups, no placeholders.'
                : 'চলমান নেটিভ ম্যাক অ্যাপ থেকে স্বয়ংক্রিয়ভাবে সংগৃহীত। কোনো ভুয়া বা ফেক মকআপ নয়।'}
            </p>
          </div>
          <Link
            to="/screenshots"
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-gray-100 hover:bg-gray-200 text-gray-800 text-sm font-semibold transition-colors shrink-0"
          >
            <span>{t.viewGallery}</span>
            <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {screenshotsList.slice(0, 6).map((item) => (
            <div
              key={item.id}
              onClick={() => setSelectedLightboxItem(item)}
              className="group cursor-pointer rounded-2xl bg-white border border-gray-200/80 p-2 shadow-xs hover:shadow-xl transition-all"
            >
              <div className="aspect-[16/10] overflow-hidden rounded-xl bg-gray-100">
                <img
                  src={item.lightSrc}
                  alt={lang === 'en' ? item.titleEn : item.titleBn}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>
              <div className="p-3 space-y-1">
                <h4 className="text-sm font-bold text-gray-900 group-hover:text-blue-600 transition-colors">
                  {lang === 'en' ? item.titleEn : item.titleBn}
                </h4>
                <p className="text-xs text-gray-500 line-clamp-1">
                  {lang === 'en' ? item.descriptionEn : item.descriptionBn}
                </p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* 7. FOUNDER & DEVELOPER PROFILE */}
      <section className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="p-8 sm:p-10 rounded-3xl bg-white border border-gray-200 shadow-md flex flex-col sm:flex-row items-center gap-8 text-center sm:text-left">
          <div className="relative shrink-0">
            <img
              src="/developer_avatar.png"
              onError={(e) => {
                (e.currentTarget as HTMLImageElement).src = 'https://avatars.githubusercontent.com/u/85398213?v=4';
              }}
              alt="Mohammad Ali Nayeem"
              className="w-28 h-28 sm:w-32 sm:h-32 rounded-full border-4 border-blue-500/20 object-cover shadow-lg"
            />
            <div className="absolute -bottom-1 -right-1 px-2.5 py-0.5 rounded-full bg-blue-600 text-white text-[11px] font-semibold border-2 border-white shadow-xs">
              Founder
            </div>
          </div>

          <div className="space-y-3 flex-1">
            <span className="text-xs uppercase font-bold tracking-wider text-blue-600">
              {t.developerProfileTitle}
            </span>
            <h3 className="text-2xl font-bold text-gray-950">
              Mohammad Ali Nayeem
            </h3>
            <p className="text-sm text-gray-600">
              {t.developerRole}
            </p>
            <div className="inline-block px-3 py-1 rounded-md bg-emerald-50 text-emerald-700 text-xs font-semibold border border-emerald-200/60">
              {t.founderBornoSoft}
            </div>
            <p className="text-xs text-gray-500 leading-relaxed pt-1">
              {lang === 'en'
                ? 'Passionate about native Apple systems engineering, high-performance Swift architectures, privacy-preserving desktop software, and developer tooling.'
                : 'নেটিভ অ্যাপল সিস্টেম প্রোগ্রামিং, সুইফট কনকারেন্সি এবং সর্বোচ্চ গোপনীয়তা সম্পন্ন ডেস্কটপ সফটওয়্যার উন্নয়নে নিবেদিতপ্রাণ।'}
            </p>

            <div className="pt-2 flex flex-wrap items-center justify-center sm:justify-start gap-3">
              <a
                href="https://bornosoft.bd"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 transition-colors shadow-2xs"
              >
                <span>{t.visitBornoSoft}</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </a>

              <a
                href="https://github.com/kazinayeem"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-gray-100 hover:bg-gray-200 text-gray-800 text-xs font-semibold transition-colors"
              >
                <GithubIcon className="w-3.5 h-3.5" />
                <span>{t.githubProfile}</span>
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* 8. DOWNLOAD CTA BANNER */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="p-8 sm:p-12 rounded-3xl bg-blue-600 text-white text-center space-y-6 shadow-xl shadow-blue-500/20">
          <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight">
            {lang === 'en' ? 'Get Borno Pulse for macOS Today' : 'আজই ডাউনলোড করুন Borno Pulse'}
          </h2>
          <p className="max-w-xl mx-auto text-blue-100 text-sm sm:text-base leading-relaxed">
            {lang === 'en'
              ? 'Free forever, open-source under MIT, zero telemetries, and universal support for Apple Silicon & Intel Macs.'
              : 'সবার জন্য উন্মুক্ত, এমআইটি লাইসেন্সযুক্ত, সম্পূর্ণ ফ্রি এবং অ্যাপল সিলিকন ও ইন্টেল ম্যাকের জন্য অপ্টিমাইজড।'}
          </p>
          <div className="pt-2 flex flex-wrap items-center justify-center gap-3">
            <Link
              to="/download"
              className="px-6 py-3 rounded-xl bg-white text-blue-700 font-bold text-sm sm:text-base hover:bg-blue-50 shadow-md transition-all active:scale-98"
            >
              {t.downloadDMG} (18 MB)
            </Link>
            <Link
              to="/features"
              className="px-5 py-3 rounded-xl bg-blue-700 hover:bg-blue-800 text-white text-sm sm:text-base font-semibold transition-colors"
            >
              {t.exploreFeatures}
            </Link>
          </div>
        </div>
      </section>

      {/* Lightbox for Screenshots */}
      <ScreenshotLightbox
        item={selectedLightboxItem}
        items={screenshotsList}
        onClose={() => setSelectedLightboxItem(null)}
        onSelect={(item) => setSelectedLightboxItem(item)}
      />
    </div>
  );
};
