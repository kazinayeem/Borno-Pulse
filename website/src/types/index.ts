export type Language = 'en' | 'bn';

export interface ScreenshotItem {
  id: string;
  titleEn: string;
  titleBn: string;
  descriptionEn: string;
  descriptionBn: string;
  category: 'telemetry' | 'developer' | 'files' | 'settings' | 'widget';
  lightSrc: string;
  darkSrc: string;
}

export interface FeatureModule {
  id: string;
  iconName: string;
  titleEn: string;
  titleBn: string;
  taglineEn: string;
  taglineBn: string;
  descriptionEn: string;
  descriptionBn: string;
  category: 'monitoring' | 'developer' | 'productivity' | 'system';
  screenshotLight: string;
  screenshotDark: string;
  highlightsEn: string[];
  highlightsBn: string[];
}

export interface FAQItem {
  id: string;
  questionEn: string;
  questionBn: string;
  answerEn: string;
  answerBn: string;
  category: 'general' | 'installation' | 'privacy' | 'developer';
}
