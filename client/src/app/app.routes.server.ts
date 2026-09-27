import { RenderMode, ServerRoute } from '@angular/ssr';

// Single-page app: prerender "/" to static HTML at build time (no Node server at runtime).
export const serverRoutes: ServerRoute[] = [
  { path: '**', renderMode: RenderMode.Prerender },
];
