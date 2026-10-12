import React, { useState } from 'react';
import { useLanguage } from '../context/LanguageContext';
import {
  Cpu,
  Laptop,
  Sparkles,
  Network,
  Keyboard,
  ChevronRight,
} from 'lucide-react';


export const DocsPage: React.FC = () => {
  const { lang } = useLanguage();
  const [activeSection, setActiveSection] = useState<string>('architecture');

  const docSections = [
    {
      id: 'architecture',
      titleEn: '1. Architecture & Swift 6 Concurrency',
      titleBn: '১. আর্কিটেকচার ও সুইফট ৬ কনকারেন্সি',
      icon: <Cpu className="w-4 h-4" />,
      contentEn: `
Borno Pulse is built natively using Swift 6 strict concurrency checking with zero backward compatibility hacks.
- **Darwin Mach Layer**: Fetches per-core CPU load and virtual memory page statistics directly from the Mach kernel via host_processor_info and host_statistics64.
- **IOKit Power Management**: Power assertions and battery decay telemetry interface with IOPMAssertionCreateWithName and IOPSCopyPowerSourcesInfo without private API violations.
- **Metal 3 Framework**: Low-overhead GPU utilization monitoring without continuous rendering passes.
- **AppKit & SwiftUI Interop**: Uses native AppKit NSWindow, NSStatusItem, and NSDraggingDestination bridges encapsulated cleanly in pure SwiftUI containers.
      `,
      contentBn: `
Borno Pulse সম্পূর্ণ আধুনিক সুইফট ৬ কঠোর কনকারেন্সি আর্কিটেকচারে তৈরি।
- **ডারউইন ম্যাক কার্নেল লেয়ার**: host_processor_info এবং host_statistics64 এর মাধ্যমে সরাসরি প্রতিটি কোরের ব্যবহার ও মেমোরি পৃষ্ঠা পরিসংখ্যান পড়ে।
- **আইওকিট পাওয়ার ম্যানেজমেন্ট**: অ্যাপলের অফিসিয়াল আইওপিএম অ্যাসার্শন এবং ব্যাটারি ক্ষয়ের সমীকরণ পরিচালনা করে।
- **মেটাল ৩ ফ্রেমওয়ার্ক**: অতিরিক্ত ব্যাটারি খরচ ছাড়া মেটাল পাইপলাইন ও জিপিইউ ব্যবহার পর্যবেক্ষণ করে।
- **অ্যাপকিট ও সুইফটইউআই সংযোগ**: নেটিভ NSWindow, NSStatusItem ও ক্যানভাস এডিটর সুইফটইউআইয়ের সাথে নিরবচ্ছিন্নভাবে যুক্ত।
      `,
    },
    {
      id: 'clamshell',
      titleEn: '2. Clamshell Mode (Lid-Closed Operation)',
      titleBn: '২. ক্ল্যামশেল মোড অপারেশন',
      icon: <Laptop className="w-4 h-4" />,
      contentEn: `
When you close your MacBook lid, macOS normally triggers system sleep unless an external display and AC charger are connected.
- **Sleep Assertion Mechanism**: Borno Pulse's ClamshellManager creates an assertion of type kIOPMAssertionTypePreventUserIdleSystemSleep with name "Borno Pulse Clamshell Background Task".
- **Hardware Readiness Audit**: Evaluates laptop model, AC charging status, and external display availability to inform the user of system state.
- **Safe Duration Timers**: Presets (1h, 2h, 3h, custom, or continuous) manage automatic teardown so battery is never drained unintentionally.
- **Clean Teardown**: Upon app termination or manual stop, all assertions are instantly released via IOPMAssertionRelease.
      `,
      contentBn: `
সাধারণত ম্যাকবুকের ঢাকনা বন্ধ করলে স্লিপ মোডে চলে যায়, যদি না এক্সটার্নাল ডিসপ্লে ও চার্জার যুক্ত থাকে।
- **স্লিপ প্রতিরোধ সমীকরণ**: Borno Pulse এর ClamshellManager সিস্টেমকে জানায় যে ব্যাকগ্রাউন্ড প্রসেস চলমান রয়েছে।
- **হার্ডওয়্যার প্রস্তুতি অডিট**: চার্জার, ল্যাপটপ মডেল এবং ডিসপ্লে কনফিগারেশন রিয়েল-টাইম যাচাই করে।
- **নিরাপদ টাইমার**: নির্দিষ্ট সময় (১ঘণ্টা, ২ঘণ্টা, ৩ঘণ্টা ইত্যাদি) পর স্বয়ংক্রিয়ভাবে স্লিপ সক্ষম করে যাতে ব্যাটারি খরচ না হয়।
- **ক্লিন টার্মিনেশন**: অ্যাপ বন্ধ বা ইউজার স্টপ চাপলে সাথে সাথে সমস্ত অ্যাসার্শন অবমুক্ত করা হয়।
      `,
    },
    {
      id: 'cleaner',
      titleEn: '3. System Cleaner & Safety Invariants',
      titleBn: '৩. সিস্টেম ক্লিনার ও নিরাপত্তা নিয়মাবলী',
      icon: <Sparkles className="w-4 h-4" />,
      contentEn: `
The System Cleaner is designed with mathematical safety guarantees:
- **Project Boundary Checks**: A folder named node_modules is only scanned and presented for cleanup if an enclosing directory contains a valid package.json or lockfile.
- **Strict Target Scoping**: Deletion routines only delete the target node_modules directory itself.
- **Never Touched**: Project source code, .git repositories, package.json, lockfiles, and environment files (.env) are strictly immutable to the cleaner.
- **Reclaimable Space Simulation**: Complete dry-run simulations calculate exact space to be freed before any deletion confirmation.
      `,
      contentBn: `
সিস্টেম ক্লিনার কঠোর নিরাপত্তা নিশ্চয়তা নিয়ে পরিচালিত:
- **প্রজেক্ট সীমানা যাচাই**: কেবল তখনই node_modules স্ক্যান করা হয় যখন ফোল্ডারে বৈধ package.json বা লকফাইল বিদ্যমান থাকে।
- **নির্দিষ্ট টার্গেট ডিলেশন**: শুধুমাত্র চিহ্নিত node_modules বা ক্যাশ ফোল্ডার মোছা হয়।
- **কখনোই মোছা হয় না**: মূল সোর্স কোড, .git ফোল্ডার, কনফিগারেশন এবং .env ফাইল সবসময় ১০০% সুরক্ষিত।
- **স্পেস সিমুলেশন রিপোর্ট**: মুছে ফেলার আগেই কতটুকু স্থান মুক্ত হবে তা নিখুঁতভাবে হিসাব করে দেখানো হয়।
      `,
    },
    {
      id: 'port_manager',
      titleEn: '4. BSD Port Auditor & Dev Servers',
      titleBn: '৪. বিএসডি পোর্ট অডিটর ও সার্ভার',
      icon: <Network className="w-4 h-4" />,
      contentEn: `
Port Scanner directly reads listening TCP and UDP sockets:
- Correlates socket descriptors with local process identifiers (PID).
- Automatically identifies common dev environments (Next.js :3000, Vite :5173, Django :8000, FastAPI :8000, PostgreSQL :5432, Redis :6379).
- Correlates processes with running Docker containers.
- Redacts sensitive CLI arguments like Authorization headers and API keys from process arguments.
      `,
      contentBn: `
পোর্ট স্ক্যানার সরাসরি ডারউইন সকেট নিরীক্ষা করে:
- লোকাল প্রসেস পিআইডি (PID) এর সাথে পোর্টের সংযোগ নিশ্চিত করে।
- প্রচলিত ফ্রেমওয়ার্ক সনাক্তকরণ (Next.js, Vite, Django, Redis, Postgres)।
- সক্রিয় ডকার কন্টেইনারের সাথে পোর্ট ম্যাপিং।
- কমান্ড লাইনের পাসওয়ার্ড ও এপিআই কি স্বয়ংক্রিয়ভাবে গোপন করে।
      `,
    },
    {
      id: 'shortcuts',
      titleEn: '5. Global Keyboard Shortcuts',
      titleBn: '৫. গ্লোবাল কিবোর্ড শর্টকাট',
      icon: <Keyboard className="w-4 h-4" />,
      contentEn: `
Borno Pulse is designed for keyboard-driven workflows:
- **⌘K**: Open Quick Launcher (Command Palette) across all 25 modules.
- **⌘O**: Show main application window from background or menu bar.
- **⌘,**: Open Settings & Preferences.
- **⌘W**: Close window (orders out window while keeping background menu bar active).
- **⌘Q**: Completely quit application and tear down all system assertions.
      `,
      contentBn: `
কিবোর্ড দিয়ে দ্রুত কাজের জন্য তৈরি শর্টকাট:
- **⌘K**: যেকোনো স্থান থেকে কুইক লঞ্চার কমান্ড প্যালেট ওপেন করুন।
- **⌘O**: ব্যাকগ্রাউন্ড থেকে মূল ড্যাশবোর্ড উইন্ডো সামনে আনুন।
- **⌘,**: সেটিংস ও প্রেফারেন্স উইন্ডো খুলুন।
- **⌘W**: উইন্ডো হাইড করুন (ব্যাকগ্রাউন্ড উইজেট সচল থাকবে)।
- **⌘Q**: অ্যাপটি সম্পূর্ণ বন্ধ করুন ও সব রিসোর্স মুক্ত করুন।
      `,
    },
  ];

  const currentSection = docSections.find((s) => s.id === activeSection) || docSections[0];

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-10">
      <div className="text-center max-w-3xl mx-auto space-y-3">
        <span className="text-xs font-bold uppercase tracking-widest text-blue-600">
          {lang === 'en' ? 'Technical Manual & Reference' : 'টেকনিক্যাল ম্যানুয়াল ও গাইড'}
        </span>
        <h1 className="text-4xl font-extrabold text-gray-950 tracking-tight">
          {lang === 'en' ? 'Borno Pulse Documentation' : 'Borno Pulse ডকুমেন্টেশন'}
        </h1>
        <p className="text-sm text-gray-600">
          {lang === 'en'
            ? 'In-depth architecture specifications, Darwin API details, safety guarantees, and configuration guides.'
            : 'সিস্টেম আর্কিটেকচার, ডারউইন এপিআই ব্যবহার, নিরাপত্তা নিশ্চিতকরণ এবং কনফিগারেশন নির্দেশিকা।'}
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-8 items-start">
        {/* Navigation Sidebar */}
        <div className="p-3 rounded-2xl bg-white border border-gray-200/90 shadow-xs space-y-1">
          {docSections.map((sec) => (
            <button
              key={sec.id}
              onClick={() => setActiveSection(sec.id)}
              className={`w-full text-left px-3.5 py-2.5 rounded-xl text-xs font-semibold flex items-center justify-between transition-colors ${
                activeSection === sec.id
                  ? 'bg-blue-600 text-white shadow-2xs'
                  : 'text-gray-700 hover:bg-gray-100'
              }`}
            >
              <div className="flex items-center gap-2 truncate">
                {sec.icon}
                <span className="truncate">{lang === 'en' ? sec.titleEn : sec.titleBn}</span>
              </div>
              <ChevronRight className="w-3.5 h-3.5 shrink-0 opacity-60" />
            </button>
          ))}
        </div>

        {/* Documentation Content Area */}
        <div className="md:col-span-3 p-8 rounded-3xl bg-white border border-gray-200/90 shadow-xs space-y-6">
          <div className="flex items-center gap-2.5 text-blue-600">
            {currentSection.icon}
            <h2 className="text-xl font-bold text-gray-950">
              {lang === 'en' ? currentSection.titleEn : currentSection.titleBn}
            </h2>
          </div>

          <div className="text-sm text-gray-700 leading-relaxed whitespace-pre-line border-t border-gray-100 pt-4">
            {lang === 'en' ? currentSection.contentEn.trim() : currentSection.contentBn.trim()}
          </div>
        </div>
      </div>
    </div>
  );
};
