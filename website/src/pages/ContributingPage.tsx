import React from 'react';
import { useLanguage } from '../context/LanguageContext';
import {
  GitPullRequest,
  Terminal,
  Languages,
  Bug,
} from 'lucide-react';
import { GithubIcon } from '../components/GithubIcon';


export const ContributingPage: React.FC = () => {
  const { lang } = useLanguage();

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-12">
      {/* Header */}
      <div className="text-center space-y-3">
        <span className="text-xs font-bold uppercase tracking-widest text-blue-600">
          {lang === 'en' ? 'Open-Source Community' : 'ওপেন সোর্স কন্ট্রিবিউশন'}
        </span>
        <h1 className="text-4xl font-extrabold text-gray-950 tracking-tight">
          {lang === 'en' ? 'Contributing to Borno Pulse' : 'Borno Pulse-এ কন্ট্রিবিউট করুন'}
        </h1>
        <p className="text-sm text-gray-600 leading-relaxed max-w-2xl mx-auto">
          {lang === 'en'
            ? 'Borno Pulse is an open-source community effort. We welcome pull requests, bug reports, feature suggestions, and translation enhancements.'
            : 'Borno Pulse একটি উন্মুক্ত কমিউনিটি প্রজেক্ট। কোড উন্নয়ন, বাগ রিপোর্ট এবং বাংলা ও ইংরেজি অনুবাদ সমৃদ্ধ করতে আপনার স্বাগতম।'}
        </p>
      </div>

      {/* Contribution Pillars */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
        <div className="p-6 rounded-2xl bg-white border border-gray-200 shadow-xs space-y-3">
          <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
            <GitPullRequest className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-gray-900 text-sm">
            {lang === 'en' ? 'Code & Swift 6 Features' : 'কোড ও নতুন ফিচার'}
          </h3>
          <p className="text-xs text-gray-600 leading-relaxed">
            {lang === 'en'
              ? 'Implement new Darwin utilities, enhance telemetry models, or optimize Metal rendering passes.'
              : 'নতুন ম্যাক ইউটিলিটি কোড লিখুন, পারফরম্যান্স বাড়ান এবং ডারউইন এপিআই সমৃদ্ধ করুন।'}
          </p>
        </div>

        <div className="p-6 rounded-2xl bg-white border border-gray-200 shadow-xs space-y-3">
          <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
            <Languages className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-gray-900 text-sm">
            {lang === 'en' ? 'Bilingual Localization' : 'বাংলা ও ইংরেজি অনুবাদ'}
          </h3>
          <p className="text-xs text-gray-600 leading-relaxed">
            {lang === 'en'
              ? 'Refine natural Bengali phrasing, technical vocabulary, and help make documentation clear in both languages.'
              : 'প্রাকৃতিক ও সাবলীল বাংলা অনুবাদ এবং প্রযুক্তিগত পরিভাষা নিখুঁত করতে সাহায্য করুন।'}
          </p>
        </div>

        <div className="p-6 rounded-2xl bg-white border border-gray-200 shadow-xs space-y-3">
          <div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
            <Bug className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-gray-900 text-sm">
            {lang === 'en' ? 'Bug Reports & Testing' : 'বাগ রিপোর্ট ও পরীক্ষণ'}
          </h3>
          <p className="text-xs text-gray-600 leading-relaxed">
            {lang === 'en'
              ? 'Test on diverse Apple Silicon (M1/M2/M3/M4) and Intel hardware configurations and report edge cases.'
              : 'বিভিন্ন ম্যাক মডেলে টেস্ট করে কোনো সমস্যা পেলে বিস্তারিত তথ্য সহ গিটহাবে ইস্যু তৈরি করুন।'}
          </p>
        </div>
      </div>

      {/* Step-by-Step Workflow */}
      <div className="p-8 rounded-3xl bg-white border border-gray-200/90 shadow-xs space-y-6">
        <h3 className="text-xl font-bold text-gray-950 flex items-center gap-2">
          <Terminal className="w-5 h-5 text-blue-600" />
          <span>{lang === 'en' ? 'Development Workflow' : 'ডেভেলপমেন্ট প্রক্রিয়া'}</span>
        </h3>

        <div className="space-y-4 text-xs sm:text-sm text-gray-700 leading-relaxed">
          <div className="p-4 rounded-xl bg-gray-50 border border-gray-200/80 space-y-2">
            <span className="font-bold text-gray-900">1. Fork & Clone Repository</span>
            <p className="font-mono text-xs text-blue-600">
              git clone https://github.com/&lt;your-username&gt;/Borno-Pulse.git
            </p>
          </div>

          <div className="p-4 rounded-xl bg-gray-50 border border-gray-200/80 space-y-2">
            <span className="font-bold text-gray-900">2. Create Feature Branch</span>
            <p className="font-mono text-xs text-blue-600">
              git checkout -b feat/your-feature-name
            </p>
          </div>

          <div className="p-4 rounded-xl bg-gray-50 border border-gray-200/80 space-y-2">
            <span className="font-bold text-gray-900">3. Run Automated Tests</span>
            <p className="text-xs text-gray-600">
              {lang === 'en'
                ? 'Always verify that all 900+ automated invariant tests pass before opening a pull request:'
                : 'পুল রিকোয়েস্ট পাঠানোর আগে নিশ্চিত করুন সব টেস্ট সফলভাবে পাস করেছে:'}
            </p>
            <p className="font-mono text-xs text-blue-600">
              "/Applications/Borno Pulse.app/Contents/MacOS/Borno Pulse" --run-tests
            </p>
          </div>

          <div className="p-4 rounded-xl bg-gray-50 border border-gray-200/80 space-y-2">
            <span className="font-bold text-gray-900">4. Commit & Submit Pull Request</span>
            <p className="text-xs text-gray-600">
              {lang === 'en'
                ? 'Push your branch and open a PR against origin/main. Follow semantic commit messages.'
                : 'আপনার ব্রাঞ্চ পুশ করে origin/main-এ পুল রিকোয়েস্ট তৈরি করুন।'}
            </p>
          </div>
        </div>
      </div>

      {/* GitHub Call to Action */}
      <div className="p-6 rounded-2xl bg-gray-900 text-white flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="space-y-1 text-center sm:text-left">
          <h4 className="font-bold text-base">
            {lang === 'en' ? 'Join Us on GitHub' : 'গিটহাবে আমাদের সাথে যুক্ত হোন'}
          </h4>
          <p className="text-xs text-gray-400">
            {lang === 'en' ? 'Star the repository, open discussions, and help build the best Mac utility.' : 'রিপোজিটরি স্টার করুন এবং ম্যাকের সেরা ইউটিলিটি তৈরিতে অংশ নিন।'}
          </p>
        </div>
        <a
          href="https://github.com/kazinayeem/Borno-Pulse"
          target="_blank"
          rel="noopener noreferrer"
          className="px-5 py-2.5 rounded-xl bg-white text-gray-900 font-bold text-xs hover:bg-gray-100 flex items-center gap-2 transition-colors shrink-0"
        >
          <GithubIcon className="w-4 h-4" />
          <span>github.com/kazinayeem/Borno-Pulse</span>
        </a>
      </div>
    </div>
  );
};
