export interface LinkItem {
  label: string;
  url: string;
  /** Short tooltip text for the hero button. Optional; the template falls back to a generic hint. */
  description?: string | null;
}

export interface SkillItem {
  label: string;
  signal: number;
}

export interface SkillGroup {
  name: string;
  items: SkillItem[];
}

export interface Role {
  title: string;
  company: string;
  location: string;
  start: string;
  end: string | null;
  bullets: string[];
  tech: string[];
}

export interface Education {
  degree: string;
  school: string;
  year: string;
  location: string;
  highlights: string[];
  studyAbroad: string[];
  organizations: string[];
}

export interface Profile {
  name: string;
  location: string;
  email: string;
  headline: string;
  summary: string;
  links: LinkItem[];
  skills: SkillGroup[];
  experience: Role[];
  education: Education[];
}
