import React, { useState } from 'react';
import { useLanguage } from '../context/LanguageContext';
import { uiTranslations } from '../i18n/translations';
import {
  Download,
  Check,
  Copy,
  Terminal,
  ShieldAlert,
  Apple,
  FileArchive,
  ExternalLink,
} from 'lucide-react';


export const DownloadPage: React.FC = () => {
  const { lang } = useLanguage();
  const t = uiTranslations[lang];
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const checksums = [
    {
      file: 'Borno-Pulse-v1.3.0.dmg',
      format: 'Apple Disk Image (UDZO)',
      size: '18 MB',
      sha256: '7e4b91c750970ec7b8c602a89a8d512883c2b951a412df9b01bc7edfae9b14bb',
      directUrl: 'https://github.com/kazinayeem/Borno-Pulse/raw/main/releases/Borno-Pulse-macOS.dmg',
    },
    {
      file: 'Borno-Pulse-macOS.zip',
      format: 'ZIP Application Archive',
      size: '15 MB',
      sha256: 'c0d8c722015add22991e49f15567dcf90bd609955def0f7a3a7231e8a041d0ef',
      directUrl: 'https://github.com/kazinayeem/Borno-Pulse/releases',
    },
  ];

  const copyToClipboard = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-16">
      {/* Page Title */}
      <div className="text-center max-w-3xl mx-auto space-y-4">
        <span className="text-xs font-bold uppercase tracking-widest text-blue-600">
          {lang === 'en' ? 'Direct Downloads & Releases' : 'সরাসরি ডাউনলোড ও ইনস্টলেশন'}
        </span>
        <h1 className="text-4xl sm:text-5xl font-extrabold text-gray-950 tracking-tight">
          {lang === 'en' ? 'Download Borno Pulse for macOS' : 'ম্যাকের জন্য Borno Pulse ডাউনলোড'}
        </h1>
        <p className="text-base text-gray-600 leading-relaxed">
          {lang === 'en'
            ? 'Free and open-source under the MIT license. Optimized for Apple Silicon (M1/M2/M3/M4) and Intel 64-bit architecture.'
            : 'এমআইটি লাইসেন্সের অধীনে সম্পূর্ণ ফ্রি ও উন্মুক্ত। অ্যাপল সিলিকন ও ইন্টেল প্রসেসরের জন্য শতভাগ অপ্টিমাইজড।'}
        </p>
      </div>

      {/* Primary Download Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* DMG Card */}
        <div className="p-8 rounded-3xl bg-white border border-gray-200/90 shadow-md space-y-6 flex flex-col justify-between">
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-12 h-12 rounded-2xl bg-blue-50 text-blue-600 flex items-center justify-center">
                <Apple className="w-6 h-6" />
              </div>
              <span className="text-xs font-bold px-2.5 py-1 rounded-full bg-blue-100 text-blue-800">
                Recommended
              </span>
            </div>
            <div>
              <h3 className="text-2xl font-bold text-gray-950">
                {lang === 'en' ? 'macOS Disk Image (.dmg)' : 'ম্যাকওএস ডিস্ক ইমেজ (.dmg)'}
              </h3>
              <p className="text-xs text-gray-500 font-medium">Borno-Pulse-v1.3.0.dmg • 18 MB • Universal Binary</p>
            </div>
            <p className="text-sm text-gray-600 leading-relaxed">
              {lang === 'en'
                ? 'Standard macOS drag-and-drop installer. Mount the DMG image, drag Borno Pulse into your Applications folder, and launch.'
                : 'সবচেয়ে সহজ পদ্ধতি। ডিস্ক ইমেজটি ওপেন করে সরাসরি আপনার Applications ফোল্ডারে টেনে এনে ইনস্টল করুন।'}
            </p>
          </div>

          <div className="space-y-3 pt-2">
            <a
              href="https://github.com/kazinayeem/Borno-Pulse/raw/main/releases/Borno-Pulse-macOS.dmg"
              className="w-full py-3.5 px-4 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-center flex items-center justify-center gap-2 shadow-sm transition-all active:scale-98"
            >
              <Download className="w-5 h-5" />
              <span>{lang === 'en' ? 'Download DMG Installer' : 'DMG ইনস্টলার ডাউনলোড'}</span>
            </a>
            <div className="text-center text-[11px] text-gray-400">
              {lang === 'en' ? 'Target: macOS 14.0+ (Sonoma, Sequoia+)' : 'প্রয়োজন: ম্যাকওএস ১৪.০+ (Sonoma, Sequoia+)'}
            </div>
          </div>
        </div>

        {/* ZIP Card */}
        <div className="p-8 rounded-3xl bg-white border border-gray-200/90 shadow-md space-y-6 flex flex-col justify-between">
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="w-12 h-12 rounded-2xl bg-indigo-50 text-indigo-600 flex items-center justify-center">
                <FileArchive className="w-6 h-6" />
              </div>
              <span className="text-xs font-bold px-2.5 py-1 rounded-full bg-gray-100 text-gray-700">
                Alternative
              </span>
            </div>
            <div>
              <h3 className="text-2xl font-bold text-gray-950">
                {lang === 'en' ? 'ZIP Archive (.zip)' : 'জিপ আর্কাইভ (.zip)'}
              </h3>
              <p className="text-xs text-gray-500 font-medium">Borno-Pulse-macOS.zip • 15 MB • Clean Bundle</p>
            </div>
            <p className="text-sm text-gray-600 leading-relaxed">
              {lang === 'en'
                ? 'Portable compressed app bundle. Extract the zip archive with built-in Archive Utility and move Borno Pulse into Applications.'
                : 'পোর্টেবল কম্প্রেসড অ্যাপ বান্ডেল। আনজিপ করে সরাসরি অ্যাপটি আপনার ম্যাকের Applications ফোল্ডারে নিয়ে যান।'}
            </p>
          </div>

          <div className="space-y-3 pt-2">
            <a
              href="https://github.com/kazinayeem/Borno-Pulse/releases"
              target="_blank"
              rel="noopener noreferrer"
              className="w-full py-3.5 px-4 rounded-xl bg-gray-900 hover:bg-black text-white font-bold text-center flex items-center justify-center gap-2 shadow-sm transition-all active:scale-98"
            >
              <ExternalLink className="w-5 h-5" />
              <span>{lang === 'en' ? 'Download via GitHub Releases' : 'গিটহাব রিলিজ থেকে ডাউনলোড'}</span>
            </a>
            <div className="text-center text-[11px] text-gray-400">
              {lang === 'en' ? 'Versioned assets & release notes' : 'ভার্সনড ফাইল ও রিলিজ নোটস'}
            </div>
          </div>
        </div>
      </div>

      {/* SHA-256 Checksums */}
      <div className="p-6 sm:p-8 rounded-3xl bg-white border border-gray-200/90 shadow-xs space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-lg font-bold text-gray-950">
              {lang === 'en' ? 'SHA-256 Checksums Manifest' : 'SHA-256 নিরাপত্তা চেকসাম'}
            </h3>
            <p className="text-xs text-gray-500">
              {lang === 'en'
                ? 'Verify artifact integrity before installation using shasum in Terminal'
                : 'টার্মিনালে shasum রান করে ডাউনলোডকৃত ফাইলের বিশুদ্ধতা নিশ্চিত করুন'}
            </p>
          </div>
        </div>

        <div className="space-y-3">
          {checksums.map((item) => (
            <div
              key={item.file}
              className="p-3.5 rounded-xl bg-gray-50 border border-gray-200/80 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs"
            >
              <div className="space-y-1">
                <span className="font-bold text-gray-900">{item.file}</span>
                <span className="text-gray-400 ml-2">({item.size})</span>
                <div className="font-mono text-[11px] text-gray-600 break-all">{item.sha256}</div>
              </div>

              <button
                onClick={() => copyToClipboard(item.sha256, item.file)}
                className="px-3 py-1.5 rounded-lg bg-white border border-gray-200 text-gray-700 font-semibold hover:bg-gray-100 flex items-center gap-1.5 shrink-0 transition-colors shadow-2xs"
              >
                {copiedKey === item.file ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-emerald-600" />
                    <span>Copied</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5" />
                    <span>Copy Hash</span>
                  </>
                )}
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Gatekeeper Security Notice */}
      <div className="p-6 sm:p-8 rounded-3xl bg-amber-50/80 border border-amber-200 text-amber-950 space-y-4">
        <div className="flex items-center gap-2.5 text-amber-900 font-bold text-base">
          <ShieldAlert className="w-5 h-5 text-amber-700" />
          <span>{lang === 'en' ? 'macOS Gatekeeper First-Launch Guidance' : 'ম্যাকওএস গেটকিপার নির্দেশনা'}</span>
        </div>
        <p className="text-xs sm:text-sm text-amber-900/90 leading-relaxed">
          {lang === 'en'
            ? 'Because this open-source community release is built directly from GitHub without proprietary paid Apple Developer ID notarization, macOS may show a developer prompt on first launch. To clear the quarantine attribute safely:'
            : 'যেহেতু এটি সম্পূর্ণ উন্মুক্ত ও ওপেন সোর্স প্রজেক্ট এবং কোনো বাণিজ্যিক অ্যাপল সার্টিফিকেটে সাইন করা নয়, ম্যাকওএস প্রথমবার চালু করার সময় ডেভেলপার সতর্কবার্তা দেখাতে পারে। এটি অনায়াসে ক্লিয়ার করতে টার্মিনালে নিচের কমান্ডটি রান করুন:'}
        </p>
        <div className="p-3 rounded-xl bg-amber-900/10 border border-amber-300 font-mono text-xs flex items-center justify-between gap-2 overflow-x-auto">
          <code>xattr -cr "/Applications/Borno Pulse.app"</code>
          <button
            onClick={() => copyToClipboard('xattr -cr "/Applications/Borno Pulse.app"', 'gatekeeper')}
            className="p-1 rounded bg-amber-200/80 hover:bg-amber-300 text-amber-900 shrink-0"
            title="Copy command"
          >
            {copiedKey === 'gatekeeper' ? <Check className="w-4 h-4 text-emerald-800" /> : <Copy className="w-4 h-4" />}
          </button>
        </div>
      </div>

      {/* Step-by-Step Installation Instructions */}
      <div className="space-y-6">
        <h3 className="text-2xl font-bold text-gray-950">
          {t.installInstructions}
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Method A: DMG */}
          <div className="p-6 rounded-2xl bg-white border border-gray-200 shadow-xs space-y-3">
            <h4 className="font-bold text-gray-900 text-base flex items-center gap-2">
              <span className="w-6 h-6 rounded-full bg-blue-100 text-blue-600 text-xs flex items-center justify-center font-bold">1</span>
              Method A — DMG Disk Image
            </h4>
            <ol className="space-y-2 text-xs text-gray-600 list-decimal list-inside leading-relaxed">
              <li>{t.stepDMG1}</li>
              <li>{t.stepDMG2}</li>
              <li>{t.stepDMG3}</li>
              <li>{t.stepDMG4}</li>
            </ol>
          </div>

          {/* Method B: ZIP */}
          <div className="p-6 rounded-2xl bg-white border border-gray-200 shadow-xs space-y-3">
            <h4 className="font-bold text-gray-900 text-base flex items-center gap-2">
              <span className="w-6 h-6 rounded-full bg-indigo-100 text-indigo-600 text-xs flex items-center justify-center font-bold">2</span>
              Method B — ZIP Archive
            </h4>
            <ol className="space-y-2 text-xs text-gray-600 list-decimal list-inside leading-relaxed">
              <li>{lang === 'en' ? 'Download Borno-Pulse-macOS.zip from Releases.' : 'রিলিজ পেজ থেকে Borno-Pulse-macOS.zip ডাউনলোড করুন।'}</li>
              <li>{lang === 'en' ? 'Extract the zip archive to reveal Borno Pulse.app.' : 'জিপ ফাইলটি আনপ্যাক করে অ্যাপটি বের করুন।'}</li>
              <li>{lang === 'en' ? 'Move the application into your /Applications directory.' : 'অ্যাপটিকে /Applications ফোল্ডারে রাখুন।'}</li>
              <li>{lang === 'en' ? 'Launch the application from Applications or Spotlight.' : 'অ্যাপ্লিকেশন ফোল্ডার থেকে অ্যাপটি ওপেন করুন।'}</li>
            </ol>
          </div>
        </div>
      </div>

      {/* Build from Source Section */}
      <div className="p-8 rounded-3xl bg-gray-900 text-white border border-gray-800 space-y-6">
        <div className="space-y-2">
          <div className="flex items-center gap-2 text-xs font-semibold text-blue-400 uppercase tracking-widest">
            <Terminal className="w-4 h-4" />
            <span>{lang === 'en' ? 'For Developers & Maintainers' : 'ডেভেলপার ও কন্ট্রিবিউটরদের জন্য'}</span>
          </div>
          <h3 className="text-2xl font-bold">
            {lang === 'en' ? 'Build from Source with Xcode' : 'সোর্স কোড থেকে এক্সকোড দিয়ে বিল্ড'}
          </h3>
          <p className="text-xs text-gray-400">
            {lang === 'en'
              ? 'Prerequisites: macOS 14.0+, Xcode 15.0+ with Swift 6 toolchain installed.'
              : 'প্রয়োজনীয়তা: ম্যাকওএস ১৪.০+, এক্সকোড ১৫.০+ ও সুইফট ৬ কম্পাইলার।'}
          </p>
        </div>

        <div className="space-y-3 font-mono text-xs">
          <div className="p-3.5 rounded-xl bg-gray-950 border border-gray-800 space-y-2">
            <p className="text-gray-500"># 1. Clone the repository</p>
            <p className="text-emerald-400">git clone https://github.com/kazinayeem/Borno-Pulse.git</p>
            <p className="text-gray-500"># 2. Open project in Xcode or build via terminal</p>
            <p className="text-emerald-400">cd "Borno-Pulse"</p>
            <p className="text-emerald-400">xcodebuild -project "smart tool.xcodeproj" -scheme "smart tool" -configuration Release build</p>
            <p className="text-gray-500"># 3. Package universal DMG and ZIP</p>
            <p className="text-emerald-400">./scripts/package-release.sh --install</p>
          </div>
        </div>
      </div>
    </div>
  );
};
