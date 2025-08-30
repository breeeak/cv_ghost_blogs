(function(){
  const root = document.documentElement;
  const dropdown = document.querySelector('.theme-dropdown');
  if(!dropdown) return;

  const toggleBtn = dropdown.querySelector('.theme-toggle');
  const menu = dropdown.querySelector('#theme-menu');
  const items = Array.from(menu.querySelectorAll('.menu-item'));
  const icon = dropdown.querySelector('.theme-icon');

  function getSunIcon(){
    return '<svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"></path></svg>';
  }

  function getMoonIcon(){
    return '<svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>';
  }

  const darkMedia = window.matchMedia('(prefers-color-scheme: dark)');

  function updateIcon(mode){
    if(mode==='auto'){
      icon.innerHTML = darkMedia.matches ? getMoonIcon() : getSunIcon();
      return;
    }
    icon.innerHTML = mode==='dark' ? getMoonIcon() : getSunIcon();
  }

  function apply(mode){
    if(mode==='auto'){
      root.removeAttribute('data-theme');
    }else{
      root.dataset.theme = mode;
    }
    items.forEach(it=>it.setAttribute('aria-checked', String(it.dataset.mode===mode)));
    updateIcon(mode);
  }

  let mode = localStorage.getItem('theme-mode') || 'auto';
  apply(mode);

  function openMenu(){
    menu.hidden = false;
    toggleBtn.setAttribute('aria-expanded','true');
  }
  function closeMenu(){
    menu.hidden = true;
    toggleBtn.setAttribute('aria-expanded','false');
  }

  toggleBtn.addEventListener('click', ()=>{
    const expanded = toggleBtn.getAttribute('aria-expanded')==='true';
    if(expanded){ closeMenu(); } else { openMenu(); }
  });

  menu.addEventListener('click', (e)=>{
    const btn = e.target.closest('.menu-item');
    if(!btn) return;
    mode = btn.dataset.mode;
    localStorage.setItem('theme-mode', mode);
    apply(mode);
    closeMenu();
  });

  document.addEventListener('click', (e)=>{
    if(!dropdown.contains(e.target)) closeMenu();
  });

  // When following system (auto), reflect OS theme changes on icon
  darkMedia.addEventListener('change', ()=>{
    if(mode==='auto') updateIcon('auto');
  });
})();


// Simple horizontal carousel controls with auto-scroll
(function(){
  const arrows = document.querySelectorAll('.carousel-arrow');
  function getTrack(target){
    return document.getElementById(`carousel-${target}`);
  }
  
  // Manual arrow controls
  arrows.forEach((btn)=>{
    btn.addEventListener('click', ()=>{
      const target = btn.dataset.target;
      const track = getTrack(target);
      if(!track) return;
      const direction = btn.classList.contains('next') ? 1 : -1;
      const amount = track.clientWidth * 0.9;
      track.scrollBy({ left: direction * amount, behavior: 'smooth' });
    });
  });

  // Auto-scroll functionality
  const carousels = [
    { id: 'exp', el: getTrack('exp') },
    { id: 'projects', el: getTrack('projects') }
  ].filter(c => c.el);

  carousels.forEach(({ id, el }) => {
    let isPaused = false;
    let direction = 1; // 1 for right, -1 for left
    let animationId;
    let userPauseUntil = 0; // timestamp until which auto-scroll is paused due to user action
    const speed = 1.2; // pixels per frame (more obvious)

    function autoScroll() {
      const now = performance.now();
      const shouldPause = isPaused || now < userPauseUntil;
      if (!shouldPause) {
        el.scrollLeft += direction * speed;
        const maxScroll = el.scrollWidth - el.clientWidth;
        if (el.scrollLeft <= 0) {
          direction = 1;
          userPauseUntil = now + 400; // short pause at edges
        } else if (el.scrollLeft >= maxScroll - 1) {
          direction = -1;
          userPauseUntil = now + 400;
        }
      }
      animationId = requestAnimationFrame(autoScroll);
    }

    // Start auto-scroll immediately
    autoScroll();

    // Wheel: avoid double-scrolling jitter on trackpads
    el.addEventListener('wheel', (e) => {
      const absX = Math.abs(e.deltaX);
      const absY = Math.abs(e.deltaY);
      const now = performance.now();
      // If horizontal intent is stronger, let native scrolling handle it
      if (absX > absY + 2) {
        userPauseUntil = now + 1500;
        return; // no manual scroll, no preventDefault
      }
      // If vertical intent is stronger, translate to horizontal and prevent default to avoid jitter
      if (absY > absX + 2) {
        el.scrollLeft += e.deltaY;
        userPauseUntil = now + 1500;
        e.preventDefault();
      }
      // Otherwise (tiny deltas), do nothing
    }, { passive: false });

    // Build bottom controls (replace side arrows)
    const container = el.closest('.carousel');
    if (container) {
      // Hide existing arrow buttons if present
      container.querySelectorAll('.carousel-arrow').forEach(btn => btn.setAttribute('hidden', 'hidden'));

      const controls = document.createElement('div');
      controls.className = 'carousel-controls';

      const prevBtn = document.createElement('button');
      prevBtn.className = 'carousel-control prev';
      prevBtn.type = 'button';
      prevBtn.setAttribute('aria-label', 'Previous');
      prevBtn.textContent = '‹';

      const nextBtn = document.createElement('button');
      nextBtn.className = 'carousel-control next';
      nextBtn.type = 'button';
      nextBtn.setAttribute('aria-label', 'Next');
      nextBtn.textContent = '›';

      controls.appendChild(prevBtn);
      controls.appendChild(nextBtn);
      container.appendChild(controls);

      function handleArrow(directionFactor) {
        const amount = el.clientWidth * 0.9;
        el.scrollBy({ left: directionFactor * amount, behavior: 'smooth' });
        userPauseUntil = performance.now() + 1200;
      }

      prevBtn.addEventListener('click', () => handleArrow(-1));
      nextBtn.addEventListener('click', () => handleArrow(1));
    }
  });
})();

// Mobile menu toggle
(function(){
  const toggle = document.querySelector('.menu-toggle');
  const panel = document.getElementById('mobile-menu');
  if(!toggle || !panel) return;
  function open(){ panel.hidden = false; toggle.setAttribute('aria-expanded','true'); }
  function close(){ panel.hidden = true; toggle.setAttribute('aria-expanded','false'); }
  toggle.addEventListener('click', ()=>{
    const expanded = toggle.getAttribute('aria-expanded')==='true';
    if(expanded){ close(); } else { open(); }
  });
  // Close when clicking outside
  document.addEventListener('click', (e)=>{
    if(panel.contains(e.target) || toggle.contains(e.target)) return;
    close();
  });
})();


// Language dropdown: like theme menu, switch between / and /zh/ and show current language icon/text
(function(){
  const dropdown = document.querySelector('.lang-dropdown');
  if(!dropdown) return;

  const toggleBtn = dropdown.querySelector('.lang-toggle');
  const menu = dropdown.querySelector('#lang-menu');
  const items = Array.from(menu.querySelectorAll('.menu-item'));
  const icon = dropdown.querySelector('.lang-icon');

  function toChinese(pathname){
    if(pathname === '/') return '/zh/';
    if(pathname.startsWith('/zh/')) return pathname;
    return '/zh' + pathname;
  }
  function toEnglish(pathname){
    if(pathname.startsWith('/zh/')) return pathname.slice(3) || '/';
    return pathname;
  }
  function isZh(pathname){
    return pathname === '/zh/' || pathname.startsWith('/zh/');
  }

  // Helpers for post detail pages
  function getAltMeta(lang){
    const meta = document.querySelector(`meta[name="alt-lang-${lang}"]`);
    return meta && meta.getAttribute('content');
  }
  function isPostPath(pathname){
    return /^\/(zh\/)?blog\/[A-Za-z0-9\-]+\/?$/.test(pathname);
  }
  function computeCounterpartForPost(pathname, targetLang){
    // If author provides explicit mapping meta, use it first
    const metaUrl = getAltMeta(targetLang);
    if(metaUrl) return metaUrl;
    // Fallback: slug convention — zh uses "-zh" suffix
    const m = pathname.match(/^\/(zh\/)?blog\/([A-Za-z0-9\-]+)\/?$/);
    if(!m) return null;
    const isCurrentZh = Boolean(m[1]);
    const slug = m[2];
    if(targetLang === 'zh'){
      const zhSlug = slug.endsWith('-zh') ? slug : slug + '-zh';
      return `/zh/blog/${zhSlug}/`;
    } else {
      const enSlug = slug.endsWith('-zh') ? slug.slice(0, -3) : slug;
      return `/blog/${enSlug}/`;
    }
  }

  // Update <html lang> and icon
  function applyIcon(){
    const zh = isZh(location.pathname);
    try { document.documentElement.setAttribute('lang', zh ? 'zh' : 'en'); } catch(e){}
    // Use compact label; you can swap to SVG if desired
    icon.textContent = zh ? '中' : 'EN';
    items.forEach(it => it.setAttribute('aria-checked', String((it.dataset.lang === (zh ? 'zh' : 'en')))));
    // Toggle navs
    document.querySelectorAll('.nav-en').forEach(el => el.hidden = !!zh);
    document.querySelectorAll('.nav-zh').forEach(el => el.hidden = !zh);
  }

  function openMenu(){ menu.hidden = false; toggleBtn.setAttribute('aria-expanded','true'); }
  function closeMenu(){ menu.hidden = true; toggleBtn.setAttribute('aria-expanded','false'); }

  applyIcon();

  toggleBtn.addEventListener('click', ()=>{
    const expanded = toggleBtn.getAttribute('aria-expanded')==='true';
    if(expanded){ closeMenu(); } else { openMenu(); }
  });

  menu.addEventListener('click', (e)=>{
    const btn = e.target.closest('.menu-item');
    if(!btn) return;
    const lang = btn.dataset.lang;
    const { pathname, search, hash } = window.location;
    let target = null;
    // If we are on a post page, try to find mapped counterpart first
    if(isPostPath(pathname)){
      target = computeCounterpartForPost(pathname, lang);
    }
    // Otherwise or if no mapping, fall back to prefix toggle
    if(!target){
      target = lang === 'zh' ? toChinese(pathname) : toEnglish(pathname);
    }
    const url = target + (search || '') + (hash || '');
    window.location.href = url;
  });

  document.addEventListener('click', (e)=>{
    if(!dropdown.contains(e.target)) closeMenu();
  });
})();


