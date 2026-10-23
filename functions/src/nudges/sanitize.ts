const urlPattern = /https?:\/\/\S+|www\.\S+/gi;
const maxNameLength = 40;

export function sanitizeDisplayName(raw: unknown): string {
  if (typeof raw !== 'string') return '';
  const text = raw.replace(urlPattern, '').replace(/\s+/g, ' ').trim();
  // by code point so an emoji is never cut in half
  return Array.from(text).slice(0, maxNameLength).join('');
}
