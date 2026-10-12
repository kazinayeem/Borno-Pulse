import React, { useState } from 'react';
import { useLanguage } from '../context/LanguageContext';
import { faqList } from '../data/featuresData';
import { ChevronDown, HelpCircle, Search } from 'lucide-react';

export const FAQPage: React.FC = () => {
  const { lang } = useLanguage();
  const [openId, setOpenId] = useState<string | null>('is-free');
  const [searchQuery, setSearchQuery] = useState<string>('');

  const toggle = (id: string) => {
    setOpenId(openId === id ? null : id);
  };

  const filteredFaqs = faqList.filter((item) => {
    const q = searchQuery.toLowerCase();
    return (
      item.questionEn.toLowerCase().includes(q) ||
      item.questionBn.toLowerCase().includes(q) ||
      item.answerEn.toLowerCase().includes(q) ||
      item.answerBn.toLowerCase().includes(q)
    );
  });

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-12">
      {/* Header */}
      <div className="text-center space-y-3">
        <span className="text-xs font-bold uppercase tracking-widest text-blue-600">
          {lang === 'en' ? 'Frequently Asked Questions' : 'সাধারণ জিজ্ঞাসা ও উত্তর'}
        </span>
        <h1 className="text-4xl font-extrabold text-gray-950 tracking-tight">
          {lang === 'en' ? 'Got Questions? We Have Answers' : 'সচরাচর জিজ্ঞাসিত প্রশ্নাবলী'}
        </h1>
        <p className="text-sm text-gray-600 leading-relaxed max-w-2xl mx-auto">
          {lang === 'en'
            ? 'Everything you need to know about licensing, offline privacy, Clamshell Mode safety, and macOS installation.'
            : 'লাইসেন্স, অফলাইন নিরাপত্তা, ক্ল্যামশেল মোড এবং ম্যাকওএস ইনস্টলেশন সম্পর্কিত প্রয়োজনীয় সকল তথ্য।'}
        </p>
      </div>

      {/* Search Input */}
      <div className="relative max-w-lg mx-auto">
        <Search className="w-4 h-4 text-gray-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder={lang === 'en' ? 'Search questions...' : 'প্রশ্ন খুঁজুন...'}
          className="w-full pl-10 pr-4 py-2.5 text-xs sm:text-sm rounded-xl border border-gray-200 bg-white focus:outline-hidden focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 shadow-2xs"
        />
      </div>

      {/* FAQ Accordion List */}
      <div className="space-y-4">
        {filteredFaqs.map((faq) => {
          const isOpen = openId === faq.id;

          return (
            <div
              key={faq.id}
              className="rounded-2xl bg-white border border-gray-200/90 shadow-2xs overflow-hidden transition-colors"
            >
              <button
                onClick={() => toggle(faq.id)}
                className="w-full px-6 py-4.5 text-left flex items-center justify-between gap-4 hover:bg-gray-50/80 transition-colors"
              >
                <span className="font-bold text-gray-900 text-sm sm:text-base">
                  {lang === 'en' ? faq.questionEn : faq.questionBn}
                </span>
                <ChevronDown
                  className={`w-4 h-4 text-gray-500 shrink-0 transition-transform duration-200 ${
                    isOpen ? 'rotate-180 text-blue-600' : ''
                  }`}
                />
              </button>

              {isOpen && (
                <div className="px-6 pb-5 pt-1 text-xs sm:text-sm text-gray-600 leading-relaxed border-t border-gray-100">
                  {lang === 'en' ? faq.answerEn : faq.answerBn}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Still Have Questions Box */}
      <div className="p-8 rounded-3xl bg-blue-50/80 border border-blue-200/80 text-center space-y-3">
        <HelpCircle className="w-8 h-8 text-blue-600 mx-auto" />
        <h3 className="font-bold text-gray-900 text-base">
          {lang === 'en' ? 'Have a different question or suggestion?' : 'আরও কোনো প্রশ্ন বা মতামত আছে?'}
        </h3>
        <p className="text-xs text-gray-600 max-w-md mx-auto">
          {lang === 'en'
            ? 'Open an issue or join GitHub Discussions to connect directly with the developers.'
            : 'সরাসরি প্রশ্ন করতে বা নতুন ফিচার প্রস্তাব করতে গিটহাব ডিসকাশন বা ইস্যুতে যুক্ত হোন।'}
        </p>
        <div className="pt-2">
          <a
            href="https://github.com/kazinayeem/Borno-Pulse/discussions"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 transition-colors shadow-2xs"
          >
            <span>{lang === 'en' ? 'Open GitHub Discussions' : 'গিটহাব ডিসকাশনে যান'}</span>
          </a>
        </div>
      </div>
    </div>
  );
};
