(() => {
  // Keep the copyright year current without requiring a new site render.
  document.querySelectorAll('[data-current-year]').forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });

  const table = document.getElementById('principles-table');
  const buttons = document.querySelectorAll('.view-button');
  const selector = document.getElementById('prompt-builder');
  const checkboxes = [...document.querySelectorAll('.principle-select')];
  const rowToggles = [...document.querySelectorAll('.select-principle')];
  const principleRows = [...document.querySelectorAll('.principle-row')];
  const principleChoices = [...document.querySelectorAll('.principle-choice')];

  /* Normalize prompt-builder entries so scrollspy/navigation work with both
     newly rendered markup and older rendered HTML that used <label> rows. */
  principleChoices.forEach((choice) => {
    const checkbox = choice.querySelector('.principle-select');
    if (!checkbox) return;
    const id = checkbox.value;
    choice.dataset.principle = id;

    let jump = choice.querySelector('.principle-jump');
    if (!jump) {
      const titleSpan = [...choice.querySelectorAll('span')].find(
        (span) => !span.classList.contains('choice-number')
      );
      if (titleSpan) {
        jump = document.createElement('a');
        jump.className = 'principle-jump';
        jump.href = `#${id}`;
        jump.textContent = titleSpan.textContent;
        titleSpan.replaceWith(jump);
      }
    }
  });
  const selectionCount = document.getElementById('selection-count');
  const copySelected = document.getElementById('copy-selected');
  const selectAll = document.getElementById('select-all');
  const clearSelection = document.getElementById('clear-selection');

  buttons.forEach((button) => {
    button.addEventListener('click', () => {
      const view = button.dataset.view;
      table.dataset.view = view;
      buttons.forEach((b) => b.classList.toggle('is-active', b === button));
    });
  });

  async function copyText(text, button) {
    try {
      await navigator.clipboard.writeText(text);
      const original = button.textContent;
      button.textContent = 'Copied';
      setTimeout(() => { button.textContent = original; }, 1200);
    } catch (_) {
      button.textContent = 'Copy failed';
    }
  }

  document.querySelectorAll('.copy-one').forEach((button) => {
    button.addEventListener('click', () => copyText(button.dataset.copy, button));
  });

  function setSelected(id, selected) {
    const checkbox = checkboxes.find((item) => item.value === id);
    const row = document.getElementById(id);
    const toggle = rowToggles.find((item) => item.dataset.principle === id);

    if (checkbox) checkbox.checked = selected;
    row?.classList.toggle('is-selected', selected);
    if (toggle) {
      toggle.classList.toggle('is-selected', selected);
      toggle.setAttribute('aria-pressed', selected ? 'true' : 'false');
      toggle.textContent = selected ? 'Selected' : 'Add';
    }
  }

  function updateSelection() {
    const selected = checkboxes.filter((checkbox) => checkbox.checked);
    selectionCount.textContent = `${selected.length} of ${checkboxes.length} selected`;
    copySelected.disabled = selected.length === 0;
    checkboxes.forEach((checkbox) => setSelected(checkbox.value, checkbox.checked));
  }

  checkboxes.forEach((checkbox) => {
    checkbox.addEventListener('change', updateSelection);
  });

  rowToggles.forEach((button) => {
    button.addEventListener('click', () => {
      const checkbox = checkboxes.find((item) => item.value === button.dataset.principle);
      if (!checkbox) return;
      checkbox.checked = !checkbox.checked;
      updateSelection();
    });
  });

  selectAll?.addEventListener('click', () => {
    checkboxes.forEach((checkbox) => { checkbox.checked = true; });
    updateSelection();
  });

  clearSelection?.addEventListener('click', () => {
    checkboxes.forEach((checkbox) => { checkbox.checked = false; });
    updateSelection();
  });

  copySelected?.addEventListener('click', () => {
    const selectedIds = new Set(
      checkboxes.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value)
    );
    const directives = principleRows
      .filter((row) => selectedIds.has(row.id))
      .map((row) => {
        const title = row.querySelector('.principle-label h2')?.textContent.trim();
        const text = row.querySelector('.copy-one')?.dataset.copy.trim();
        return `# ${title}\n\n${text}`;
      })
      .join('\n\n');

    if (directives) copyText(directives, copySelected);
  });

  /* Scroll-aware TOC behavior. The active principle is the row whose top is
     closest to the reading line near the upper quarter of the viewport. */
  let activeId = null;
  let tocFrame = null;

  function setActivePrinciple(id) {
    if (!id || id === activeId) return;
    activeId = id;

    principleRows.forEach((row) => {
      row.classList.toggle('is-active-principle', row.id === id);
    });

    principleChoices.forEach((choice) => {
      const isActive = choice.dataset.principle === id;
      choice.classList.toggle('is-active', isActive);
      const link = choice.querySelector('.principle-jump');
      if (link) {
        if (isActive) link.setAttribute('aria-current', 'location');
        else link.removeAttribute('aria-current');
      }
    });

    const activeChoice = principleChoices.find((choice) => choice.dataset.principle === id);
    if (activeChoice) {
      const list = activeChoice.closest('.principle-checklist');
      if (list) {
        const choiceTop = activeChoice.offsetTop;
        const choiceBottom = choiceTop + activeChoice.offsetHeight;
        const visibleTop = list.scrollTop;
        const visibleBottom = visibleTop + list.clientHeight;
        if (choiceTop < visibleTop || choiceBottom > visibleBottom) {
          activeChoice.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }
      }
    }
  }

  function updateActivePrinciple() {
    tocFrame = null;
    if (!principleRows.length) return;

    const readingLine = Math.min(window.innerHeight * 0.24, 190);
    let active = principleRows[0];

    for (const row of principleRows) {
      const rect = row.getBoundingClientRect();
      if (rect.top <= readingLine) active = row;
      if (rect.top > readingLine) break;
    }

    const lastRow = principleRows[principleRows.length - 1];
    if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2) {
      active = lastRow;
    }

    setActivePrinciple(active.id);
  }

  function scheduleActiveUpdate() {
    if (tocFrame !== null) return;
    tocFrame = window.requestAnimationFrame(updateActivePrinciple);
  }

  window.addEventListener('scroll', scheduleActiveUpdate, { passive: true });
  window.addEventListener('resize', scheduleActiveUpdate);

  document.querySelectorAll('.principle-jump').forEach((link) => {
    link.addEventListener('click', (event) => {
      const id = link.getAttribute('href')?.slice(1);
      const row = id ? document.getElementById(id) : null;
      if (!row) return;
      event.preventDefault();
      row.scrollIntoView({ block: 'start', behavior: 'smooth' });
      history.replaceState(null, '', `#${id}`);
      setActivePrinciple(id);
    });
  });

  const mobileToggle = document.getElementById('prompt-builder-toggle');
  mobileToggle?.addEventListener('click', () => {
    const expanded = mobileToggle.getAttribute('aria-expanded') === 'true';
    mobileToggle.setAttribute('aria-expanded', expanded ? 'false' : 'true');
    selector?.classList.toggle('is-open', !expanded);
  });

  updateSelection();
  updateActivePrinciple();
})();
