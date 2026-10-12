"""Shared Playwright helpers for the PackDrop suites.

Why this exists
---------------
Two traps cost a lot of time in this suite and both look like product bugs:

1. DAILY_CAP is 4. Every pack opened consumes one, so any suite that runs after
   a few packs in the same browser profile finds the allowance spent. onPackTap()
   then bails out with a toast and the pack sits there completely inert: the
   element is present, the handler fires, nothing happens. Without knowing to
   look, that reads as "the pack is broken".
   -> grant_packs() tops the allowance up from the save.

2. A pack is not tappable until the card pools and artwork have loaded. A fixed
   sleep is not a readiness signal, and on a loaded box the pack is still
   unready long after any sleep worth writing.
   -> wait_pack_ready() asserts on the actual conditions.
"""

CHROME = '/opt/hermes/.playwright/chromium-1243/chrome-linux64/chrome'
URL = 'http://127.0.0.1:8899/index.html?dev=1'
KEY = 'pd:packdrop-profile-v1'

# The pack is genuinely openable when it is sized, split into halves, AND
# carries .tappable. That class is added in the same statement that binds the
# click listener, at the end of an async init, so it is the one signal that
# means "a tap here will actually open a pack" rather than "the art is drawn".
PACK_READY_JS = (
    "() => { const p = document.getElementById('pack-el');"
    " if (!p) return false;"
    " const r = p.getBoundingClientRect();"
    " return r.width > 40 && r.height > 40 &&"
    " p.classList.contains('tappable') &&"
    " p.querySelectorAll('.pack-half').length > 0; }"
)

GRANT_PACKS_JS = """(n) => {
    const K = 'pd:packdrop-profile-v1';
    let d; try { d = JSON.parse(localStorage.getItem(K) || '{}'); } catch (e) { d = {}; }
    const t = new Date();
    const date = t.getFullYear() + '-' + String(t.getMonth()+1).padStart(2,'0')
               + '-' + String(t.getDate()).padStart(2,'0');
    d.packsLeft = { date: date, left: n };
    localStorage.setItem(K, JSON.stringify(d));
}"""


def ensure_server(url, tries=3):
    """Fail fast with a clear message if the local test server is not up.

    Without this a dead server surfaces as ERR_CONNECTION_REFUSED from deep
    inside the first page.goto(), which reads like a product failure.
    """
    import urllib.request
    for i in range(tries):
        try:
            urllib.request.urlopen(url, timeout=4)
            return True
        except Exception:
            if i == tries - 1:
                raise SystemExit(
                    f'TEST SERVER NOT REACHABLE at {url}\n'
                    f'  start it:  cd /opt/data/projects/packdrop && '
                    f'.venv/bin/python -m http.server 8899')
            import time; time.sleep(1)


def wait_pack_ready(page, timeout=90000):
    """Block until the pack element is present, sized, and split into halves."""
    page.wait_for_function(PACK_READY_JS, timeout=timeout)
    page.wait_for_timeout(1000)


def grant_packs(page, n=40):
    """Top up the daily pack allowance, then reload so the app reads it.

    Called before any pack tap. Without this the pack is silently inert once
    four packs have been opened in the same profile.
    """
    page.evaluate(GRANT_PACKS_JS, n)
    page.reload(wait_until='domcontentloaded')
    try:
        wait_pack_ready(page)
    except Exception:
        page.wait_for_timeout(3000)


def dismiss_overlays(page):
    """Clear the account nudge and anything else that swallows clicks.

    The nudge is triggered by opening a pack and sits above everything, so it
    reappears in the middle of a run and intercepts the next navigation. The
    first-run coach marks are pointer-events:none so they never block a tap,
    but they are cleared here too so assertions never see a stray spotlight.
    """
    page.evaluate(
        "() => { try { document.getElementById('nudge-dismiss')?.click(); } catch (e) {} "
        " try { document.getElementById('account-nudge-overlay')"
        "?.classList.remove('active'); } catch (e) {} "
        " document.querySelectorAll('.coach').forEach(el => el.remove()); }"
    )


def tap_pack(page, tries=12, wait=4000):
    """Click the pack element itself, retrying until the reveal actually opens.

    A coordinate tap on #pack-stage was landing on the pack's glow rather than
    on the element carrying the listener, so the pack never opened.

    Retrying matters because wait_pack_ready() returning does NOT mean the pack
    is openable: the click listener is bound at the end of an async init, so on
    a loaded box a single tap can land before that and do nothing. A fixed sleep
    is the wrong tool — long enough when the machine is idle is still too short
    when several browser suites are competing for CPU. The reveal overlay going
    active is the only honest signal that the pack opened, so wait on it.
    """
    for _ in range(tries):
        page.evaluate(
            "() => { const p = document.getElementById('pack-el'); if (p) p.click(); }")
        try:
            page.wait_for_function(
                "() => { const o = document.getElementById('reveal-overlay');"
                " return o && o.classList.contains('active'); }", timeout=wait)
            return True
        except Exception:
            continue
    return False


def reveal_all(page, tries=90):
    """Reveal every card and finish the pack, returning the summary payout.

    Two rules learned from watching the reveal state:
      - never click the card while it is already flipped (that flips it BACK and
        loops forever on the same slot);
      - never click advance while it is hidden (it only appears after the
        reveal's dwell delay, which is up to 1850ms on the top tier).
    The commit is async, so settle before reading saved state.
    """
    for _ in range(tries):
        st = page.evaluate(
            "() => { const ov = document.getElementById('reveal-overlay');"
            " const btn = document.getElementById('advance-btn');"
            " const card = document.getElementById('rs-card');"
            " return { active: ov ? ov.classList.contains('active') : false,"
            " btnReady: btn ? !btn.classList.contains('hidden') : false,"
            " flipped: card ? card.classList.contains('flipped') : true }; }"
        )
        if not st['active']:
            break
        if st['btnReady']:
            page.evaluate("() => document.getElementById('advance-btn').click()")
        elif not st['flipped']:
            page.evaluate(
                "() => { const c = document.getElementById('rs-card'); if (c) c.click(); }")
        page.wait_for_timeout(900)

    page.wait_for_timeout(2500)
    payout = page.evaluate(
        "() => (document.getElementById('summary-xp') || {}).textContent || ''")
    still_open = page.evaluate(
        "() => document.getElementById('reveal-overlay').classList.contains('active')")
    return payout, still_open
