(function () {
    'use strict';

    // ================================================================
    //  prime-episodes  (v2)
    //  Na stronie serialu zastepuje sekcje "Sezony" wyborem sezonu
    //  (przyciski) i pionowa lista odcinkow w stylu Prime Video:
    //  miniatura, numer i tytul, czas trwania, data, opis,
    //  znacznik obejrzenia / pasek postepu.
    //
    //  KONFIGURACJA:
    //  - SECTION_TITLES: naglowki sekcji do podmiany (rozne jezyki UI)
    //  - TXT: teksty wlasne latki
    // ================================================================
    var SECTION_TITLES = ['sezony', 'seasons'];
    var TXT = {
        episodes: 'Odcinki',
        season: 'Sezon',
        minutes: 'min'
    };

    var CSS = '' +
        '.jfpv{margin:.4em 0 1em}' +
        '.jfpv-seasons{display:flex;flex-wrap:wrap;gap:.5em;margin:0 0 1em}' +
        '.jfpv-pill{background:rgba(255,255,255,.12);color:inherit;border:.14em solid transparent;border-radius:2em;padding:.35em 1.1em;font:inherit;cursor:pointer}' +
        '.jfpv-pill.jfpv-active{background:#00a4dc;color:#fff}' +
        '.jfpv-pill:focus{border-color:#fff;outline:none}' +
        '.jfpv-episodes{display:flex;flex-direction:column;gap:.6em}' +
        '.jfpv-ep{display:flex;gap:1em;align-items:flex-start;text-align:left;background:rgba(255,255,255,.06);border:.14em solid transparent;border-radius:.4em;padding:.6em;color:inherit;cursor:pointer;width:100%;font:inherit}' +
        '.jfpv-ep:focus{border-color:#fff;background:rgba(255,255,255,.16);outline:none}' +
        '.jfpv-thumb{position:relative;flex:0 0 15em;height:8.4em;border-radius:.3em;overflow:hidden;background:rgba(0,0,0,.4)}' +
        '.jfpv-thumb img{width:100%;height:100%;object-fit:cover;display:block}' +
        '.jfpv-progress{position:absolute;left:0;bottom:0;height:.3em;background:#00a4dc}' +
        '.jfpv-played{position:absolute;top:.3em;right:.3em;background:#00a4dc;color:#fff;border-radius:50%;width:1.5em;height:1.5em;line-height:1.5em;text-align:center;font-size:.9em}' +
        '.jfpv-info{flex:1;min-width:0}' +
        '.jfpv-ep-title{font-weight:600;margin:0 0 .2em}' +
        '.jfpv-ep-meta{opacity:.7;font-size:.9em;margin:0 0 .35em}' +
        '.jfpv-ep-overview{opacity:.85;font-size:.92em;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}' +
        '.jfpv-host > :not(.jfpv):not(.jfpv-title){display:none !important}' +
        // Dopoki nie wiadomo, czy podmieniamy widok (trwa pobieranie danych),
        // oryginalne listy dzieci sa niewidoczne - inaczej przez chwile
        // widac stary styl sezonow, zanim wejdzie nowy.
        '.jfpv-pending #itemDetailPage #childrenCollapsible,' +
        '.jfpv-pending #itemDetailPage #listChildrenCollapsible{visibility:hidden !important}';

    function injectCss() {
        if (document.getElementById('jfpv-style')) return;
        var st = document.createElement('style');
        st.id = 'jfpv-style';
        st.textContent = CSS;
        (document.head || document.documentElement).appendChild(st);
    }

    function norm(s) { return (s || '').replace(/\s+/g, ' ').trim().toLowerCase(); }

    // --- przykrywanie starego widoku do czasu podmiany -----------------
    // Bezpiecznik: gdyby cokolwiek poszlo nie tak (brak API, blad zapytania,
    // inny typ pozycji), oryginalna zawartosc zawsze zostanie odsloniona.
    var pendingTimer = null;
    function markPending() {
        if (!isDetailsHash()) return;
        document.documentElement.classList.add('jfpv-pending');
        clearTimeout(pendingTimer);
        pendingTimer = setTimeout(clearPending, 4000);
    }
    function clearPending() {
        clearTimeout(pendingTimer);
        document.documentElement.classList.remove('jfpv-pending');
    }
    // ------------------------------------------------------------------

    function apiReady() { return !!(window.ApiClient && window.ApiClient.getCurrentUserId); }
    function hashPrefix() { return location.hash.indexOf('#!/') === 0 ? '#!' : '#'; }
    function isDetailsHash() { return /\/details\?/.test(location.hash || ''); }
    function hashParams() {
        var h = location.hash || '';
        var i = h.indexOf('?');
        var out = {};
        if (i < 0) return out;
        h.substring(i + 1).split('&').forEach(function (kv) {
            var p = kv.split('=');
            if (p[0]) out[decodeURIComponent(p[0])] = decodeURIComponent(p[1] || '');
        });
        return out;
    }
    function ticksToMin(t) { return t ? Math.round(t / 600000000) : 0; }
    function visible(el) { return !!(el && el.offsetParent !== null); }

    function findSeasonsSection() {
        var titles = document.querySelectorAll('.verticalSection .sectionTitle, .verticalSection h2');
        for (var i = 0; i < titles.length; i++) {
            var sec = titles[i].closest('.verticalSection');
            if (!sec || !visible(sec)) continue;
            if (SECTION_TITLES.indexOf(norm(titles[i].textContent)) >= 0) return sec;
            if (sec.hasAttribute('data-jfpv')) return sec; // wczesniej podmieniona, do ponownego montazu
        }
        return null;
    }

    var itemCache = {};
    var busy = false;

    function check() {
        injectCss();
        if (!apiReady() || !isDetailsHash()) { clearPending(); return; }
        var id = hashParams().id;
        if (!id) { clearPending(); return; }
        var mounted = document.querySelector('.jfpv[data-series="' + id + '"]');
        if (visible(mounted)) { clearPending(); return; }
        if (busy) return;
        var sec = findSeasonsSection();
        if (!sec) return;
        busy = true;
        var uid = ApiClient.getCurrentUserId();
        var p = itemCache[id] || (itemCache[id] = ApiClient.getItem(uid, id));
        p.then(function (item) {
            busy = false;
            // nie serial (film, sezon, album) -> odsloniamy oryginalny widok
            if (!item || item.Type !== 'Series') { clearPending(); return; }
            if (hashParams().id !== id) { clearPending(); return; }
            mount(sec, item, hashParams().serverId || item.ServerId, uid);
        }, function () { busy = false; clearPending(); });
    }

    function mount(sec, series, serverId, uid) {
        sec.classList.add('jfpv-host');
        sec.setAttribute('data-jfpv', series.Id);
        sec.innerHTML = '';

        var title = document.createElement('h2');
        title.className = 'sectionTitle jfpv-title';
        title.textContent = TXT.episodes;

        var wrap = document.createElement('div');
        wrap.className = 'jfpv';
        wrap.setAttribute('data-series', series.Id);
        var pills = document.createElement('div');
        pills.className = 'jfpv-seasons';
        var list = document.createElement('div');
        list.className = 'jfpv-episodes';
        wrap.appendChild(pills);
        wrap.appendChild(list);
        sec.appendChild(title);
        sec.appendChild(wrap);
        // nasza sekcja jest juz w DOM - mozna odsłonic strone
        clearPending();

        ApiClient.getSeasons(series.Id, { userId: uid }).then(function (res) {
            var seasons = (res && res.Items) || [];
            if (!seasons.length) return;
            seasons.forEach(function (s, idx) {
                var b = document.createElement('button');
                b.type = 'button';
                b.className = 'jfpv-pill';
                b.textContent = s.Name || (TXT.season + ' ' + (s.IndexNumber != null ? s.IndexNumber : idx + 1));
                b.addEventListener('click', function () {
                    var act = pills.querySelector('.jfpv-active');
                    if (act) act.classList.remove('jfpv-active');
                    b.classList.add('jfpv-active');
                    loadEpisodes(series, s, serverId, uid, list);
                });
                pills.appendChild(b);
            });
            pills.firstChild.classList.add('jfpv-active');
            loadEpisodes(series, seasons[0], serverId, uid, list);
        });
    }

    function loadEpisodes(series, season, serverId, uid, list) {
        list.innerHTML = '';
        ApiClient.getEpisodes(series.Id, {
            seasonId: season.Id,
            userId: uid,
            fields: 'Overview,PrimaryImageAspectRatio'
        }).then(function (res) {
            var eps = (res && res.Items) || [];
            eps.forEach(function (ep) {
                list.appendChild(renderEpisode(ep, series, serverId));
            });
        });
    }

    function renderEpisode(ep, series, serverId) {
        var row = document.createElement('button');
        row.type = 'button';
        row.className = 'jfpv-ep';

        var th = document.createElement('div');
        th.className = 'jfpv-thumb';
        var imgUrl = null;
        if (ep.ImageTags && ep.ImageTags.Primary) {
            imgUrl = ApiClient.getScaledImageUrl(ep.Id, { type: 'Primary', maxWidth: 480, tag: ep.ImageTags.Primary });
        } else if (series.BackdropImageTags && series.BackdropImageTags.length) {
            imgUrl = ApiClient.getScaledImageUrl(series.Id, { type: 'Backdrop', maxWidth: 480, tag: series.BackdropImageTags[0] });
        }
        if (imgUrl) {
            var img = document.createElement('img');
            img.loading = 'lazy';
            img.alt = '';
            img.src = imgUrl;
            th.appendChild(img);
        }
        var ud = ep.UserData || {};
        if (ud.Played) {
            var ok = document.createElement('div');
            ok.className = 'jfpv-played';
            ok.textContent = '\u2713';
            th.appendChild(ok);
        } else if (ud.PlayedPercentage) {
            var pr = document.createElement('div');
            pr.className = 'jfpv-progress';
            pr.style.width = Math.min(100, ud.PlayedPercentage) + '%';
            th.appendChild(pr);
        }

        var info = document.createElement('div');
        info.className = 'jfpv-info';
        var t = document.createElement('div');
        t.className = 'jfpv-ep-title';
        t.textContent = (ep.IndexNumber != null ? ep.IndexNumber + '. ' : '') + (ep.Name || '');
        info.appendChild(t);

        var bits = [];
        var min = ticksToMin(ep.RunTimeTicks);
        if (min) bits.push(min + ' ' + TXT.minutes);
        if (ep.PremiereDate) {
            try { bits.push(new Date(ep.PremiereDate).toLocaleDateString()); } catch (e) { /* ignoruj */ }
        }
        if (bits.length) {
            var meta = document.createElement('div');
            meta.className = 'jfpv-ep-meta';
            meta.textContent = bits.join(' \u00b7 ');
            info.appendChild(meta);
        }
        if (ep.Overview) {
            var ov = document.createElement('div');
            ov.className = 'jfpv-ep-overview';
            ov.textContent = ep.Overview;
            info.appendChild(ov);
        }

        row.appendChild(th);
        row.appendChild(info);
        row.addEventListener('click', function () {
            location.hash = hashPrefix() + '/details?id=' + ep.Id + (serverId ? '&serverId=' + serverId : '');
        });
        return row;
    }

    var scheduled = false;
    function schedule() {
        if (scheduled) return;
        scheduled = true;
        setTimeout(function () {
            scheduled = false;
            try { check(); } catch (e) { clearPending(); }
        }, 80);
    }

    new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
    window.addEventListener('hashchange', function () { markPending(); schedule(); });
    document.addEventListener('DOMContentLoaded', schedule);

    // CSS wstrzykujemy NATYCHMIAST przy wczytaniu skryptu (jest w <head>,
    // wiec przed zbudowaniem strony) - dzieki temu stary widok sezonow
    // nie miga przez chwile przed podmiana na nowy.
    injectCss();
    markPending();
    schedule();
})();