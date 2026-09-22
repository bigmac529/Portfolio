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

  onSkillFilter(event: Event): void {
    const value = ((event.target as HTMLInputElement)?.value || '').trim();
    this.skillFilter.set(value);
  }
}
