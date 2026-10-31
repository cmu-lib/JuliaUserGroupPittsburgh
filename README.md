# Julia Language User Group — Pittsburgh

A monthly gathering of Julia users at Carnegie Mellon University, hosted with CMU Libraries.

Julia is an open-source language for high-performance scientific and numerical computing. The group is a place for students, researchers, and staff to ask questions, share techniques, and see how others use Julia in their projects.

## Who is it for?

- **Any level**: beginners are welcome.
- **Any discipline**: physics, statistics, biology, engineering, the humanities, and more.
- **Any topic**: numerical methods, data analysis, machine learning, optimization, visualization, package development, reproducibility.

## When and where

| | |
|---|---|
| **Schedule** | Monthly, usually the **first Tuesday** of the month |
| **Time** | 5:00 PM |
| **Place** | Wean Hall (**WEH**) 2327, Carnegie Mellon University |

Dates sometimes change. Check the [library guide](https://guides.library.cmu.edu/JuliaPittsburgh) for the current schedule and calendar invites.

## Organizers

| Name | Contact |
|---|---|
| Leticia Madureira | leticiam@andrew.cmu.edu |
| Alfredo González-Espinoza | agonzal3@andrew.cmu.edu |
| Rachel Kurchin | rkurchin@andrew.cmu.edu |

## Links

- Official guide: <https://guides.library.cmu.edu/JuliaPittsburgh>
- CMU Libraries: <https://www.library.cmu.edu>
- Julia language: <https://julialang.org>

## About this repository

This repository will hold the group's website, built with [Franklin.jl](https://franklinjl.org), a static site generator written in Julia. Its visual style follows the group's poster.

### Adding a meeting

Create `meetings/YYYY-MM-DD.md`:

```markdown
@def title = "Differential equations with DifferentialEquations.jl"
@def meeting_date = Date(2026, 12, 1)
@def speaker = "Jane Doe"
@def status = "scheduled"   # or "postponed", "cancelled"

# {{fill title}}

{{meeting_info}}

Abstract, slides and code go here.
```

`meeting_time` and `meeting_room` default to the values in `config.md` and can be overridden per meeting. The home page and the meetings list update automatically; the site is rebuilt daily so past meetings move to the archive.

### Preview locally

With Julia 1.11 installed, from the repository root:

```julia
julia --project=. -e 'using Pkg; Pkg.instantiate(); using Franklin; serve()'
```

Then open <http://localhost:8000>. Pages reload on save.

### Deployment

Every push to `main` builds the site and publishes it to GitHub Pages through `.github/workflows/Deploy.yml`. In the repository settings, **Pages → Source** must be set to **GitHub Actions**.
