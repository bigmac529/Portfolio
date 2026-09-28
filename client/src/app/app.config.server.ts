import { ApplicationConfig, mergeApplicationConfig } from '@angular/core';
import { provideServerRendering } from '@angular/platform-server';
import { provideServerRouting } from '@angular/ssr';
import { appConfig } from './app.config';
import { serverRoutes } from './app.routes.server';
import { PROFILE_SNAPSHOT } from './profile.service';
import { Profile } from './models/profile';
// Build-time import: bundled into the server (prerender) build only, never the browser bundle.
import profileJson from '../../../Portfolio.Server/profile.json';

const profileSnapshot: Profile = profileJson;

const serverConfig: ApplicationConfig = {
  providers: [
    provideServerRendering(),
    provideServerRouting(serverRoutes),
    { provide: PROFILE_SNAPSHOT, useValue: profileSnapshot },
  ],
};

export const config = mergeApplicationConfig(appConfig, serverConfig);
