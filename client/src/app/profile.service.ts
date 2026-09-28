import { Injectable, InjectionToken, TransferState, inject, makeStateKey } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { EMPTY, Observable, catchError, concat, of, shareReplay } from 'rxjs';
import { Profile } from './models/profile';

/**
 * Provided only by the server config (app.config.server.ts) during the build-time
 * prerender, so the static index.html contains the real profile content for crawlers
 * and link-preview bots. Never provided in the browser.
 */
export const PROFILE_SNAPSHOT = new InjectionToken<Profile>('PROFILE_SNAPSHOT');

const PROFILE_STATE_KEY = makeStateKey<Profile>('profile');

@Injectable({ providedIn: 'root' })
export class ProfileService {
  readonly profile$: Observable<Profile>;

  constructor(private http: HttpClient) {
    const state = inject(TransferState);
    const snapshot = inject(PROFILE_SNAPSHOT, { optional: true });

    if (snapshot) {
      // Prerender (build time): render from profile.json and pass it to the browser
      // via TransferState so the first client render matches the static HTML.
      state.set(PROFILE_STATE_KEY, snapshot);
      this.profile$ = of(snapshot);
      return;
    }

    const live$ = this.http.get<Profile>('/api/profile');
    const prerendered = state.get(PROFILE_STATE_KEY, null);

    if (prerendered) {
      // Browser after prerender: show the baked-in profile immediately, then refresh
      // from the live API. If the API call fails, keep showing the baked-in copy.
      state.remove(PROFILE_STATE_KEY);
      this.profile$ = concat(of(prerendered), live$.pipe(catchError(() => EMPTY))).pipe(shareReplay(1));
    } else {
      this.profile$ = live$.pipe(shareReplay(1));
    }
  }
}
