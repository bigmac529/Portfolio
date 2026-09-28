import { CommonModule } from '@angular/common';
import { Component, ViewEncapsulation, signal } from '@angular/core';
import { ProfileService } from './profile.service';
import { SkillGroup } from './models/profile';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './app.component.html',
  encapsulation: ViewEncapsulation.None,
})
export class AppComponent {
  skillFilter = signal('');
  showTopSkillsOnly = signal(false);

  constructor(public svc: ProfileService) {}

  filteredSkillGroups(skills: SkillGroup[]): SkillGroup[] {
    const q = this.skillFilter().toLowerCase();
    const top = this.showTopSkillsOnly();
    let groups = skills;
    if (q) {
      groups = groups
        .map((g) => ({
          name: g.name,
          items: g.items.filter((s) => s.label.toLowerCase().includes(q)),
        }))
        .filter((g) => g.items.length > 0);
    }
    if (top) {
      groups = groups.map((g) => ({
        name: g.name,
        items: [...g.items].sort((a, b) => b.signal - a.signal).slice(0, 5),
      }));
    }
    return groups;
  }

  toggleTopSkills(): void {
    this.showTopSkillsOnly.update((v) => !v);
  }

  /**
   * Hero tooltip placement. Runs on mouseenter / focusin of the button wrapper (browser only).
   * The tooltip is centred above its button by CSS; this nudges it sideways so it stays at
   * least 8px inside the viewport, and flips it below the button when there is no room above.
   */
  showTip(event: Event): void {
    const host = event.currentTarget as HTMLElement | null;
    const tip = host?.querySelector<HTMLElement>('.hero-tip');
    if (!host || !tip) return;
    const margin = 8;
    host.classList.remove('hero-tip-dismissed', 'hero-tip-below');
    tip.style.setProperty('--tip-shift', '0px');
    const rect = tip.getBoundingClientRect();
    const viewportWidth = document.documentElement.clientWidth;
    let shift = 0;
    if (rect.left < margin) shift = margin - rect.left;
    else if (rect.right > viewportWidth - margin) shift = viewportWidth - margin - rect.right;
    tip.style.setProperty('--tip-shift', `${Math.round(shift)}px`);
    if (rect.top < margin) host.classList.add('hero-tip-below');
  }

  /** Esc hides the tooltip without moving focus (WCAG 1.4.13); it shows again on the next hover/focus. */
  hideTip(event: Event): void {
    (event.currentTarget as HTMLElement | null)?.classList.add('hero-tip-dismissed');
  }

  onSkillFilter(event: Event): void {
    const value = ((event.target as HTMLInputElement)?.value || '').trim();
    this.skillFilter.set(value);
  }
}
