import React from 'react';
import { useLanguage } from '../context/LanguageContext';
import {
  Lock,
  Database,
  CheckCircle2,
} from 'lucide-react';


export const PrivacyPage: React.FC = () => {
  const { lang } = useLanguage();

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-12">
      {/* Header */}
      <div className="text-center space-y-3">
        <span className="text-xs font-bold uppercase tracking-widest text-emerald-600">
          {lang === 'en' ? 'Uncompromising User Privacy' : 'সর্বোচ্চ ব্যবহারকারী গোপনীয়তা'}
        </span>
        <h1 className="text-4xl font-extrabold text-gray-950 tracking-tight">
          {lang === 'en' ? 'Privacy Policy & Architecture' : 'প্রাইভেসি পলিসি ও আর্কিটেকচার'}
        </h1>
        <p className="text-sm text-gray-600 leading-relaxed max-w-2xl mx-auto">
          {lang === 'en'
            ? 'Borno Pulse was engineered from day one with a 100% offline, local-first philosophy. We do not collect, transmit, monetize, or store any of your personal data.'
            : 'Borno Pulse প্রথম দিন থেকেই শতভাগ অফলাইন ও লোকাল আর্কিটেকচারে তৈরি। আপনার কোনো ব্যক্তিগত ডাটা কোথাও পাঠানো, সংগ্রহ বা বিক্রি করা হয় না।'}
        </p>
      </div>

      {/* Highlights Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
        <div className="p-6 rounded-2xl bg-white border border-gray-200 shadow-xs space-y-3">
          <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
            <Lock className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-gray-900 text-sm">
            {lang === 'en' ? 'Zero Cloud Telemetry' : 'জিরো ক্লাউড টেলিমেট্রি'}
          </h3>
          <p className="text-xs text-gray-600 leading-relaxed">
            {lang === 'en'
              ? 'No third-party analytics SDKs, crash trackers, or background beacons exist in either the macOS app or this website.'
              : 'অ্যাপ বা এই ওয়েবসাইটে কোনো গুগল অ্যানালিটিক্স, ট্র্যাকার বা থার্ড-পার্টি লাইব্রেরি যুক্ত নেই।'}
          </p>
        </div>

        <div className="p-6 rounded-2xl bg-white border border-gray-200 shadow-xs space-y-3">
          <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
            <Database className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-gray-900 text-sm">
            {lang === 'en' ? 'Strictly Local Data Storage' : 'শতভাগ লোকাল ডাটা সংরক্ষণ'}
          </h3>
          <p className="text-xs text-gray-600 leading-relaxed">
            {lang === 'en'
              ? 'All metrics, clipboard history, screen time logs, and preferences reside solely on your Mac’s local disk.'
              : 'সব মেট্রিক্স, ক্লিপবোর্ড হিস্ট্রি ও সেটিংস শুধুমাত্র আপনার ম্যাকের নিজস্ব স্টোরেজেই সীমাবদ্ধ থাকে।'}
          </p>
        </div>
      </div>

      {/* Detailed Declarations */}
      <div className="p-8 rounded-3xl bg-white border border-gray-200/90 shadow-xs space-y-8 text-xs sm:text-sm text-gray-700 leading-relaxed">
        {/* Section 1 */}
        <div className="space-y-3">
          <h3 className="text-base font-bold text-gray-950 flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-600" />
            <span>{lang === 'en' ? '1. macOS Application Privacy' : '১. ম্যাকওএস অ্যাপ্লিকেশনের গোপনীয়তা'}</span>
          </h3>
          <p>
            {lang === 'en'
              ? 'Borno Pulse operates entirely offline. The application performs no remote network requests for feature telemetry, feature gating, licensing, or metrics logging. Hardware metrics (CPU, GPU, RAM, sensors, battery) are read via Darwin Mach and IOKit APIs directly in local memory and are never sent over the network.'
              : 'Borno Pulse সম্পূর্ণ অফলাইনে কাজ করে। কোনো লাইসেন্স যাচাই বা মেট্রিক্স লগের জন্য অ্যাপটি দূরবর্তী কোনো সার্ভারের সাথে যোগাযোগ করে না। সমস্ত হার্ডওয়্যার তথ্য লোকাল মেমোরিতেই তাৎক্ষণিকভাবে প্রসেস করা হয়।'}
          </p>
        </div>

        {/* Section 2 */}
        <div className="space-y-3">
          <h3 className="text-base font-bold text-gray-950 flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-600" />
            <span>{lang === 'en' ? '2. Automated Credential & Secret Masking' : '২. স্বয়ংক্রিয় পাসওয়ার্ড ও সিক্রেট মাস্কিং'}</span>
          </h3>
          <p>
            {lang === 'en'
              ? 'In utilities that display text—such as the Clipboard Manager and the Port Manager—built-in regular expression algorithms automatically detect and redact sensitive credentials (API tokens, Bearer tokens, private keys, passwords) before displaying them in UI views.'
              : 'ক্লিপবোর্ড ম্যানেজার ও পোর্ট অডিটরের মতো টুলগুলোতে সংবেদনশীল পাসওয়ার্ড, এপিআই কি ও সিক্রেট টোকেন স্বয়ংক্রিয়ভাবে শনাক্ত করে মাস্ক বা গোপন রাখা হয়।'}
          </p>
        </div>

        {/* Section 3 */}
        <div className="space-y-3">
          <h3 className="text-base font-bold text-gray-950 flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-600" />
            <span>{lang === 'en' ? '3. Website Data & Cookies Policy' : '৩. ওয়েবসাইটের ডাটা ও কুকিজ নীতি'}</span>
          </h3>
          <p>
            {lang === 'en'
              ? 'This public website requires no registration, contains no user account system, and sets zero marketing tracking cookies. The only information stored client-side is your chosen language preference (English or Bengali) via the browser’s standard localStorage API.'
              : 'এই ওয়েবসাইটে কোনো ইউজার অ্যাকাউন্ট বা রেজিস্ট্রেশন নেই এবং কোনো ট্র্যাকিং কুকি ব্যবহার করা হয় না। শুধুমাত্র আপনার ভাষা পছন্দ (ইংরেজি বা বাংলা) ব্রাউজারের নিজস্ব লোকালস্টোরেজে সংরক্ষিত থাকে।'}
          </p>
        </div>

        {/* Section 4 */}
        <div className="space-y-3">
          <h3 className="text-base font-bold text-gray-950 flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-600" />
            <span>{lang === 'en' ? '4. Third-Party Hosting & GitHub' : '৪. গিটহাব ও থার্ড-পার্টি সেবা'}</span>
          </h3>
          <p>
            {lang === 'en'
              ? 'The project’s source code and downloadable releases are hosted publicly on GitHub. When you download installers or open issues, GitHub’s standard privacy policy applies to their network infrastructure.'
              : 'প্রজেক্টের সোর্স কোড ও রিলিজ ফাইলগুলো গিটহাবে হোস্ট করা। গিটহাব থেকে ফাইল ডাউনলোড বা ইস্যু খোলার ক্ষেত্রে গিটহাবের নিজস্ব গোপনীয়তা নীতি কার্যকর।'}
          </p>
        </div>
      </div>
    </div>
  );
};
