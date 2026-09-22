import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, shareReplay } from 'rxjs';
import { Profile } from './models/profile';

@Injectable({ providedIn: 'root' })
export class ProfileService {
  readonly profile$: Observable<Profile>;

  constructor(private http: HttpClient) {
    this.profile$ = this.http.get<Profile>('/api/profile').pipe(shareReplay(1));
  }
}
