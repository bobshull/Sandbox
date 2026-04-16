const state = {
  config: null,
  currentMonth: null,
  selectedDate: new Date()
};

const weekdayRow = document.getElementById('weekdayRow');
const calendarGrid = document.getElementById('calendarGrid');
const monthLabel = document.getElementById('monthLabel');
const selectedDateLabel = document.getElementById('selectedDateLabel');
const selectedDateMeta = document.getElementById('selectedDateMeta');
const taskList = document.getElementById('taskList');
const taskCount = document.getElementById('taskCount');
const extrasSection = document.getElementById('extrasSection');
const extrasList = document.getElementById('extrasList');
const focusBadge = document.getElementById('focusBadge');
const dayPurpose = document.getElementById('dayPurpose');
const rotationCard = document.getElementById('rotationCard');
const viewModeLabel = document.getElementById('viewModeLabel');
const datePickerBtn = document.getElementById('datePickerBtn');
const datePickerLabel = document.getElementById('datePickerLabel');
const calendarPopover = document.getElementById('calendarPopover');

const STORAGE_KEY = 'homeRhythm.selectedDate';

const todayBtn = document.getElementById('todayBtn');
const prevMonthBtn = document.getElementById('prevMonthBtn');
const nextMonthBtn = document.getElementById('nextMonthBtn');
const prevDayBtn = document.getElementById('prevDayBtn');
const nextDayBtn = document.getElementById('nextDayBtn');

init();

function init() {
  state.config = loadConfig();

  const today = new Date();
  state.selectedDate = loadSelectedDate() ?? stripTime(today);
  state.currentMonth = new Date(state.selectedDate.getFullYear(), state.selectedDate.getMonth(), 1);

  renderWeekdays();
  renderCalendar();
  renderDetails();
  wireEvents();
}

function loadConfig() {
  const embedded = document.getElementById('scheduleData');
  return JSON.parse(embedded.textContent);
}

function wireEvents() {
  todayBtn.addEventListener('click', () => {
    const today = stripTime(new Date());
    state.selectedDate = today;
    state.currentMonth = new Date(today.getFullYear(), today.getMonth(), 1);
    renderCalendar();
    renderDetails();
    closePopover();
  });

  prevMonthBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    state.currentMonth = new Date(state.currentMonth.getFullYear(), state.currentMonth.getMonth() - 1, 1);
    renderCalendar();
  });

  nextMonthBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    state.currentMonth = new Date(state.currentMonth.getFullYear(), state.currentMonth.getMonth() + 1, 1);
    renderCalendar();
  });

  prevDayBtn.addEventListener('click', () => shiftSelectedDay(-1));
  nextDayBtn.addEventListener('click', () => shiftSelectedDay(1));

  datePickerBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    togglePopover();
  });

  document.addEventListener('click', (e) => {
    if (calendarPopover.hidden) return;
    if (calendarPopover.contains(e.target) || datePickerBtn.contains(e.target)) return;
    closePopover();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closePopover();
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (e.key === 'ArrowLeft') shiftSelectedDay(-1);
    if (e.key === 'ArrowRight') shiftSelectedDay(1);
  });
}

function shiftSelectedDay(delta) {
  const d = state.selectedDate;
  state.selectedDate = stripTime(new Date(d.getFullYear(), d.getMonth(), d.getDate() + delta));
  if (state.selectedDate.getMonth() !== state.currentMonth.getMonth() ||
      state.selectedDate.getFullYear() !== state.currentMonth.getFullYear()) {
    state.currentMonth = new Date(state.selectedDate.getFullYear(), state.selectedDate.getMonth(), 1);
  }
  renderCalendar();
  renderDetails();
}

function togglePopover() {
  if (calendarPopover.hidden) openPopover();
  else closePopover();
}

function openPopover() {
  state.currentMonth = new Date(state.selectedDate.getFullYear(), state.selectedDate.getMonth(), 1);
  renderCalendar();
  calendarPopover.hidden = false;
  datePickerBtn.setAttribute('aria-expanded', 'true');
}

function closePopover() {
  calendarPopover.hidden = true;
  datePickerBtn.setAttribute('aria-expanded', 'false');
}

function renderWeekdays() {
  weekdayRow.innerHTML = '';
  state.config.weekdayOrder.forEach(day => {
    const div = document.createElement('div');
    div.className = 'weekday-cell';
    div.textContent = day.slice(0, 1);
    div.title = day;
    weekdayRow.appendChild(div);
  });
}

function renderCalendar() {
  calendarGrid.innerHTML = '';
  const year = state.currentMonth.getFullYear();
  const month = state.currentMonth.getMonth();
  monthLabel.textContent = new Intl.DateTimeFormat('en-US', {
    month: 'long',
    year: 'numeric'
  }).format(state.currentMonth);

  const firstOfMonth = new Date(year, month, 1);
  const startDay = firstOfMonth.getDay();
  const gridStart = new Date(year, month, 1 - startDay);

  for (let i = 0; i < 42; i += 1) {
    const date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + i);
    const button = document.createElement('button');
    button.className = 'day-cell';
    button.type = 'button';

    const isOutsideMonth = date.getMonth() !== month;
    const isToday = isSameDate(date, new Date());
    const isSelected = isSameDate(date, state.selectedDate);

    if (isOutsideMonth) button.classList.add('outside-month');
    if (isToday) button.classList.add('today');
    if (isSelected) button.classList.add('selected');

    button.innerHTML = `<span class="day-number">${date.getDate()}</span>`;

    button.addEventListener('click', () => {
      state.selectedDate = stripTime(date);
      if (date.getMonth() !== state.currentMonth.getMonth() || date.getFullYear() !== state.currentMonth.getFullYear()) {
        state.currentMonth = new Date(date.getFullYear(), date.getMonth(), 1);
      }
      renderCalendar();
      renderDetails();
      closePopover();
    });

    calendarGrid.appendChild(button);
  }
}

function renderDetails() {
  const date = state.selectedDate;
  saveSelectedDate(date);
  const today = stripTime(new Date());
  const isToday = isSameDate(date, today);
  const plan = getPlanForDate(date);

  viewModeLabel.textContent = isToday ? 'Today' : describeRelative(date, today);

  const longLabel = new Intl.DateTimeFormat('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric'
  }).format(date);
  selectedDateLabel.textContent = longLabel;

  const shortLabel = new Intl.DateTimeFormat('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  }).format(date);
  datePickerLabel.textContent = shortLabel;

  selectedDateMeta.textContent = isToday
    ? 'This is your plan for today.'
    : 'Tap the date above to jump to any other day.';

  focusBadge.textContent = plan.label;
  dayPurpose.textContent = plan.purpose;

  taskList.innerHTML = '';
  plan.tasks.forEach((task, idx) => {
    const li = document.createElement('li');
    const id = `task-${idx}`;
    li.innerHTML = `
      <label class="task-row">
        <input type="checkbox" id="${id}" />
        <span class="task-text"></span>
      </label>
    `;
    li.querySelector('.task-text').textContent = task;
    taskList.appendChild(li);
  });
  taskCount.textContent = plan.tasks.length === 1 ? '1 item' : `${plan.tasks.length} items`;

  extrasList.innerHTML = '';
  if (plan.extras && plan.extras.length) {
    extrasSection.hidden = false;
    plan.extras.forEach((extra, idx) => {
      const li = document.createElement('li');
      const id = `extra-${idx}`;
      li.innerHTML = `
        <label class="task-row">
          <input type="checkbox" id="${id}" />
          <span class="task-text"></span>
        </label>
      `;
      li.querySelector('.task-text').textContent = extra;
      extrasList.appendChild(li);
    });
  } else {
    extrasSection.hidden = true;
  }

  if (date.getDay() === 6) {
    rotationCard.innerHTML = `
      <strong>${escapeHtml(plan.rotation.title)}</strong>
      <span class="muted">${escapeHtml(plan.rotation.details)}</span>
    `;
  } else {
    const saturdayInfo = getRotationForSaturday(date);
    rotationCard.innerHTML = `
      <strong>Upcoming Saturday: ${escapeHtml(saturdayInfo.title)}</strong>
      <span class="muted">${escapeHtml(saturdayInfo.details)}</span>
    `;
  }
}

function describeRelative(date, today) {
  const msPerDay = 24 * 60 * 60 * 1000;
  const diffDays = Math.round((date - today) / msPerDay);
  if (diffDays === -1) return 'Yesterday';
  if (diffDays === 1) return 'Tomorrow';
  if (diffDays > 1 && diffDays < 7) return `In ${diffDays} days`;
  if (diffDays < -1 && diffDays > -7) return `${Math.abs(diffDays)} days ago`;
  return 'Selected day';
}

function getPlanForDate(date) {
  const dayKey = String(date.getDay());
  const template = state.config.dailyTemplates[dayKey];
  const plan = {
    label: template.label,
    purpose: template.purpose,
    tasks: [...template.tasks]
  };

  if (date.getDay() === 6) {
    const rotation = getRotationForSaturday(date);
    plan.rotation = rotation;
    plan.tasks = plan.tasks.map(task => (
      task.includes('current rotation') ? `${task.replace('current rotation', 'rotation')}: ${rotation.title} — ${rotation.details}` : task
    ));
  }

  plan.extras = getExtrasForDate(date);

  return plan;
}

function getExtrasForDate(date) {
  const list = state.config.recurringExtras;
  if (!Array.isArray(list)) return [];
  const dayIndex = Math.floor(stripTime(date).getTime() / 86400000);
  const parity = dayIndex % 2 === 0 ? 'even' : 'odd';
  return list
    .filter(item => item.cadence === 'everyOtherDay' && item.parity === parity)
    .map(item => item.task);
}

function getRotationForSaturday(date) {
  const saturday = getNextOrSameSaturday(date);
  const firstSaturday = getFirstSaturdayOfYear(saturday.getFullYear());
  const msPerWeek = 7 * 24 * 60 * 60 * 1000;
  const weekIndex = Math.floor((stripTime(saturday) - stripTime(firstSaturday)) / msPerWeek);
  const project = state.config.rotatingSaturdayProjects[weekIndex % state.config.rotatingSaturdayProjects.length];
  return project;
}

function getFirstSaturdayOfYear(year) {
  const jan1 = new Date(year, 0, 1);
  const diff = (6 - jan1.getDay() + 7) % 7;
  return new Date(year, 0, 1 + diff);
}

function getNextOrSameSaturday(date) {
  const cleanDate = stripTime(date);
  const diff = (6 - cleanDate.getDay() + 7) % 7;
  return new Date(cleanDate.getFullYear(), cleanDate.getMonth(), cleanDate.getDate() + diff);
}

function loadSelectedDate() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const [y, m, d] = raw.split('-').map(Number);
    if (!y || !m || !d) return null;
    return new Date(y, m - 1, d);
  } catch {
    return null;
  }
}

function saveSelectedDate(date) {
  try {
    const iso = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
    localStorage.setItem(STORAGE_KEY, iso);
  } catch {
    /* localStorage unavailable — no-op */
  }
}

function stripTime(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function isSameDate(a, b) {
  return a.getFullYear() === b.getFullYear()
    && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate();
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}
