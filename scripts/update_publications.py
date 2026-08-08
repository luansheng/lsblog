#!/usr/bin/env python3
"""Auto-maintain the Publication page (publication.qmd).

Pipeline
--------
1. Fetch all works of the OpenAlex author ID (see publications.json,
   ``openalex_author_id``) with cursor pagination.
2. Keep only works that pass the filter in publications.json:
   - journal articles only (type in ``filter.types``),
   - venue in ``filter.venue_whitelist`` (and not in ``venue_blocklist``),
   - the author is first author or last/corresponding author
     (``filter.positions``),
   - not retracted, not an erratum/correction.
3. Merge new works into the ``auto`` list of publications.json, skipping
   works that are already present (by DOI) or suppressed (see below).
   Author names come from Crossref (publisher-registered given/family)
   when available; OpenAlex display names are used as fallback.
4. Regenerate publication.qmd from publications.json (auto entries rendered
   from structured metadata, manual entries rendered verbatim), sorted by
   year descending.

How to maintain by hand
-----------------------
- Chinese-language papers are not reliably indexed by OpenAlex, so they live
  in the ``manual`` list of publications.json with their verbatim markdown in
  ``display``. Append new entries there (keep ``order`` increasing; ``year``
  is used for sorting).
- The OpenAlex author profile also contains the papers of a different
  researcher named Sheng Luan (plant biology). The venue blocklist keeps
  those out. If a wrong paper slips through anyway, add its DOI to
  ``filter.suppressed``.
- A Chinese paper may have an English-translated OpenAlex record (e.g. a
  CNKI DOI like 10.3724/...). Such a record would otherwise be added as an
  English entry; put its DOI in the manual entry's ``suppress_dois`` or in
  ``filter.suppressed``.
- publication.qmd is generated — never edit it by hand.

Requires only the Python standard library. Run:
    python3 scripts/update_publications.py
"""

import datetime
import html
import json
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request

REPO_ROOT = ''
DB_PATH = 'publications.json'
QMD_PATH = 'publication.qmd'

API = 'https://api.openalex.org/works'
# OpenAlex polite pool: include a mailto so requests are not rate-limited.
MAILTO = 'mailto:lsblog-updater@example.org'
UA = 'lsblog-publication-updater/1.0'


# ---------------------------------------------------------------- helpers

def clean_title(s):
    s = html.unescape(re.sub(r'<[^>]+>', '', s or ''))
    return re.sub(r'\s+', ' ', s).strip()


def norm_title(s):
    s = clean_title(s).lower()
    s = re.sub(r'[*.]', '', s)
    return unicodedata.normalize('NFKD', re.sub(r'\s+', ' ', s)).strip()


def venue_of(work):
    src = (work.get('primary_location') or {}).get('source') or {}
    return src.get('display_name')


def doi_of(work):
    return (work.get('doi') or '').lower().replace('https://doi.org/', '').strip()


def fmt_name(display):
    """'Ziyi Kang' -> 'Kang Ziyi' (family name last in OpenAlex)."""
    parts = (display or '?').split()
    return ' '.join([parts[-1]] + parts[:-1]) if len(parts) > 1 else display


def crossref_authors(doi):
    """Author (family, given) pairs from Crossref for a DOI, or None.

    Crossref is publisher-registered, so its given/family names are more
    reliable than OpenAlex display names, which are occasionally wrong
    (e.g. 'Tangfeng Lv' for 'Tianzan Lv') or abbreviated (e.g. 'J. Liu').
    """
    try:
        url = 'https://api.crossref.org/works/' + urllib.parse.quote(doi, safe='')
        req = urllib.request.Request(url, headers={'User-Agent': UA, 'mailto': MAILTO})
        with urllib.request.urlopen(req, timeout=30) as r:
            msg = json.load(r)['message']
        authors = []
        for a in msg.get('author', []):
            fam = (a.get('family') or '').strip()
            if fam:
                authors.append((fam, (a.get('given') or '').strip()))
        return authors or None
    except Exception:
        return None


def api_get(url, tries=3):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA, 'mailto': MAILTO})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as exc:  # network hiccup / 429 / 5xx
            last = exc
            time.sleep(5 * (i + 1))
    raise RuntimeError(f'OpenAlex request failed after {tries} tries: {last}')


def fetch_works(author_id):
    works = []
    cursor = '*'
    while cursor:
        url = f'{API}?filter=author.id:{author_id}&per-page=200&cursor={cursor}'
        data = api_get(url)
        works.extend(data['results'])
        cursor = data['meta'].get('next_cursor')
        if len(data['results']) == 0:
            break
    return works


# ---------------------------------------------------------------- filtering

def classify(work, db, existing_dois, bypass_venue=False):
    """Return (entry, None) if the work should be added, else (None, reason)."""
    f = db['filter']
    ven = venue_of(work) or '(none)'

    if not bypass_venue:
        if ven in f['venue_blocklist']:
            return None, f'venue blocklisted: {ven}'
    if (work.get('type') or '') not in f['types']:
        return None, f"type not in {f['types']}: {work.get('type')}"
    title = (work.get('title') or '').strip().lower()
    if title.startswith(('erratum', 'correction')):
        return None, 'erratum/correction'
    if work.get('is_retracted'):
        return None, 'retracted'
    if ven not in f['venue_whitelist'] and not bypass_venue:
        return None, f'venue not whitelisted: {ven}'

    # Find the tracked author: by OpenAlex cluster ID, or — for watched DOIs,
    # whose fresh papers may sit in a newly split cluster — by name.
    luan_idx = None
    for i, a in enumerate(work.get('authorships', [])):
        ad = a.get('author') or {}
        if (ad.get('id') or '').endswith(db['openalex_author_id']) or (
                bypass_venue and (ad.get('display_name') or '').strip().lower()
                in ('sheng luan', 'luan sheng')):
            luan_idx = i
            break
    if luan_idx is None:
        return None, 'tracked author not found in authorships'
    pos = work['authorships'][luan_idx]['author_position']
    # Position-only rule: OpenAlex's is_corresponding flag is noisy (some
    # works mark every author), so first/last author is the reliable proxy
    # (last author = corresponding author in the aquaculture convention).
    if pos not in f['positions']:
        return None, f'position {pos}, not in {f["positions"]}'

    doi = doi_of(work)
    if doi and doi in existing_dois:
        return None, 'already in database'
    for s in f.get('suppressed', []):
        if s.get('doi') == doi:
            return None, 'suppressed: ' + s.get('reason', '')
    for m in db['manual']:
        if doi and doi == (m.get('doi') or '').lower():
            return None, 'already a manual entry'
        if doi and doi in (m.get('suppress_dois') or []):
            return None, 'suppressed by manual entry'
    t = norm_title(title)
    for m in db['manual']:
        if t in [norm_title(x) for x in (m.get('suppress_titles') or [])]:
            return None, 'suppressed by manual entry (title)'

    b = work.get('biblio') or {}
    # Prefer Crossref given/family names: OpenAlex display names are
    # occasionally wrong ('Tangfeng Lv') or abbreviated ('J. Liu').
    cr = crossref_authors(doi) if doi else None
    authors = []
    for i, a in enumerate(work.get('authorships', [])):
        ad = a.get('author') or {}
        name = None
        if cr and i < len(cr) and cr[i][0]:
            name = f"{cr[i][0]} {cr[i][1]}".strip()
        authors.append({'name': name or fmt_name(ad.get('display_name')),
                        'is_luan': i == luan_idx})
    entry = {
        'doi': doi or None,
        'title': clean_title(work['title']),
        'authors': authors,
        'year': work.get('publication_year'),
        'venue': ven,
        'volume': b.get('volume'),
        'issue': b.get('issue'),
        'first_page': b.get('first_page'),
        'last_page': b.get('last_page'),
        'added': datetime.date.today().isoformat(),
    }
    return entry, None


# ---------------------------------------------------------------- rendering

def render_auto(e, db):
    aliases = db['filter'].get('venue_aliases', {})
    venue = aliases.get(e['venue'], e['venue'])
    authors = ', '.join(
        f"**{a['name']}**" if a.get('is_luan') else a['name'] for a in e['authors'])
    parts = [str(e['year'])]
    if e.get('volume'):
        parts.append(str(e['volume']))
    if e.get('issue'):
        parts.append(str(e['issue']))
    if e.get('first_page'):
        pg = str(e['first_page'])
        if e.get('last_page') and str(e['last_page']) != pg:
            pg += '-' + str(e['last_page'])
        parts.append(pg)
    text = f"{authors}. {e['title']}. {venue}, " + ', '.join(parts) + '.'
    if e.get('doi'):
        text += f" <https://doi.org/{e['doi']}>."
    return text


def render_qmd(db):
    entries = []
    for i, m in enumerate(db['manual']):
        entries.append(('manual', i, m))
    for i, a in enumerate(db['auto']):
        entries.append(('auto', i, a))
    entries.sort(key=lambda x: (
        -(x[2]['year'] or 0),
        0 if x[0] == 'manual' else 1,
        x[1] if x[0] == 'manual' else (x[2].get('doi') or '')))

    lines = ['---', 'title: "Publication"', 'format: html', '---', '']
    for n, (kind, _, e) in enumerate(entries, 1):
        text = e['display'] if kind == 'manual' else render_auto(e, db)
        lines.append(f'{n}.  {text}')
        lines.append('')
    return '\n'.join(lines).rstrip() + '\n'


# ------------------------------------------------------------------ main

def main():
    db = json.load(open(DB_PATH, encoding='utf-8'))
    works = fetch_works(db['openalex_author_id'])

    # Explicitly watched DOIs: papers that OpenAlex may have assigned to a
    # different (e.g. freshly split) author cluster, or venues outside the
    # whitelist (e.g. the visPedigree software paper). Venue checks are
    # bypassed for these; the first/last-author rule still applies.
    for doi in db['filter'].get('watch_dois', []):
        try:
            work = api_get(f'{API}/https://doi.org/{doi}')
            works.append(work)
        except Exception as exc:
            print(f'  ! could not fetch watched DOI {doi}: {exc}')

    existing = {e['doi'].lower() for e in db['auto'] if e.get('doi')}
    skip_log, new = [], []
    for w in works:
        entry, reason = classify(w, db, existing, bypass_venue=bool(w.get('doi') and w['doi'].lower().replace('https://doi.org/','') in db['filter'].get('watch_dois', [])))
        if entry is not None:
            new.append(entry)
            existing.add(entry['doi'] or '')
        elif reason:
            skip_log.append({
                'doi': doi_of(w) or None,
                'year': w.get('publication_year'),
                'title': clean_title(w.get('title'))[:80],
                'reason': reason,
            })

    if new:
        db['auto'] = db['auto'] + new
    db['skip_log'] = skip_log[-100:]
    db['updated'] = datetime.date.today().isoformat()

    with open(DB_PATH, 'w', encoding='utf-8') as fh:
        json.dump(db, fh, ensure_ascii=False, indent=2)
    with open(QMD_PATH, 'w', encoding='utf-8') as fh:
        fh.write(render_qmd(db))

    print(f'{len(works)} works fetched | {len(new)} new | {len(db["auto"])} auto | '
          f'{len(db["manual"])} manual | {len(skip_log)} skipped')
    for e in new:
        print(f'  + {e["year"]} | {e["venue"]} | {e["title"][:70]}')
    for s in skip_log[:10]:
        print(f"  - [{s['year']}] {s['title'][:55]}  ({s['reason']})")
    return 2 if new else 0  # 2 = changed, for the CI commit step


if __name__ == '__main__':
    sys.exit(main())
