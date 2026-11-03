/**
 * ============================================================================
 *  CREDIT RISK INTELLIGENCE — Google Apps Script backend
 * ----------------------------------------------------------------------------
 *  Membaca data pinjaman dari Google Sheets, melakukan agregasi satu-pass di
 *  server, lalu mengirim payload ringkas (< 20 KB) ke frontend.
 *
 *  Sumber data : sheet "credit_risk_clean" (32.409 baris x 15 kolom)
 *  Output      : KPI, default rate per grade/intent/DTI, risk matrix
 *                (home ownership x income band), opsi filter.
 *
 *  Deploy      : Deploy > New deployment > Web app
 *                Execute as: Me  |  Who has access: Anyone
 * ============================================================================
 */

const CONFIG = Object.freeze({
  // Kosongkan bila script terikat (container-bound) ke spreadsheet.
  // Isi dengan ID spreadsheet bila script berdiri sendiri (standalone).
  SPREADSHEET_ID: '',
  SHEET_NAME: 'credit_risk_clean',
  CACHE_TTL_SECONDS: 300, // cache hasil agregasi (5 menit)
  MEMORY_TTL_MS: 60 * 1000, // cache baris mentah di memori instance warm
  CACHE_VERSION: 'v1' // naikkan bila struktur payload berubah
});

const COLUMNS = Object.freeze({
  id: 'loan_id',
  age: 'person_age',
  income: 'person_income',
  home: 'person_home_ownership',
  emp: 'person_emp_length',
  intent: 'loan_intent',
  grade: 'loan_grade',
  amount: 'loan_amnt',
  rate: 'loan_int_rate',
  status: 'loan_status',
  pct: 'loan_percent_income',
  defFile: 'cb_person_default_on_file',
  hist: 'cb_person_cred_hist_length',
  ageGroup: 'age_group',
  band: 'income_band'
});

const GRADE_ORDER = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
const HOME_ORDER = ['RENT', 'MORTGAGE', 'OWN', 'OTHER'];
const INCOME_ORDER = ['<30K', '30-50K', '50-75K', '75-100K', '100K+'];
const INTENT_ORDER = [
  'DEBTCONSOLIDATION',
  'EDUCATION',
  'HOMEIMPROVEMENT',
  'MEDICAL',
  'PERSONAL',
  'VENTURE'
];
const DTI_TIERS = [
  { key: '<10%', label: '< 10%' },
  { key: '10-19%', label: '10–19%' },
  { key: '20-29%', label: '20–29%' },
  { key: '30-39%', label: '30–39%' },
  { key: '40%+', label: '≥ 40%' }
];

/** Cache in-memory (bertahan selama instance Apps Script masih warm). */
const MEMORY = { rows: null, version: '', at: 0, baseline: null };

/* ---------------------------------------------------------------------------
 *  WEB APP ENTRY POINT
 * ------------------------------------------------------------------------- */

function doGet() {
  return HtmlService.createTemplateFromFile('index')
    .evaluate()
    .setTitle('Credit Risk Intelligence — Portfolio Dashboard')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

/** Helper opsional bila suatu saat butuh memecah file HTML. */
function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

/* ---------------------------------------------------------------------------
 *  API: dipanggil frontend lewat google.script.run
 * ------------------------------------------------------------------------- */

/**
 * @param {{grade?:string, home?:string, intent?:string}} rawFilters
 * @return {Object} payload siap-render untuk dashboard
 */
function getDashboardData(rawFilters) {
  const filters = normalizeFilters_(rawFilters);
  const cache = CacheService.getScriptCache();
  const cacheKey = ['crd', CONFIG.CACHE_VERSION || 'v1', filters.grade, filters.home, filters.intent].join('|');

  try {
    const hit = cache.get(cacheKey);
    if (hit) {
      const parsed = JSON.parse(hit);
      parsed.meta.cached = true;
      return parsed;
    }
  } catch (err) {
    // Cache bukan hal kritikal — lanjut hitung ulang.
  }

  const started = Date.now();
  const sheet = getSheet_();
  const rows = loadRows_(sheet);
  const payload = buildDashboard_(rows, filters);

  payload.meta = {
    generatedAt: new Date().toISOString(),
    cached: false,
    durationMs: Date.now() - started,
    sheetName: sheet.getName(),
    sourceRows: rows.length
  };

  try {
    const json = JSON.stringify(payload);
    if (json.length < 95000) {
      cache.put(cacheKey, json, CONFIG.CACHE_TTL_SECONDS);
    }
  } catch (err) {
    // Abaikan kegagalan cache.
  }

  return payload;
}

/**
 * Utility untuk admin: panggil manual dari editor untuk memaksa data segar.
 * CacheService tidak menyediakan listing key, jadi entri lama akan kedaluwarsa
 * sendiri dalam CACHE_TTL_SECONDS. Untuk invalidasi instan, naikkan
 * CONFIG.CACHE_VERSION.
 */
function clearDashboardCache() {
  MEMORY.rows = null;
  MEMORY.version = '';
  MEMORY.at = 0;
  MEMORY.baseline = null;
  return 'Cache memori dibersihkan. Entri CacheService kedaluwarsa dalam ' +
    CONFIG.CACHE_TTL_SECONDS + ' detik (atau naikkan CONFIG.CACHE_VERSION).';
}

/* ---------------------------------------------------------------------------
 *  SUMBER DATA
 * ------------------------------------------------------------------------- */

function getSheet_() {
  const ss = CONFIG.SPREADSHEET_ID
    ? SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID)
    : SpreadsheetApp.getActiveSpreadsheet();

  if (!ss) {
    throw new Error(
      'Spreadsheet tidak dapat diakses. Ikat script ke spreadsheet atau isi CONFIG.SPREADSHEET_ID.'
    );
  }

  const sheet = ss.getSheetByName(CONFIG.SHEET_NAME) || ss.getSheets()[0];
  if (!sheet) throw new Error('Sheet "' + CONFIG.SHEET_NAME + '" tidak ditemukan.');
  return sheet;
}

/**
 * Membaca seluruh baris dan memetakannya ke objek ringkas.
 * Hasil disimpan di MEMORY agar request berikutnya (instance warm) instan.
 */
function loadRows_(sheet) {
  const version = sheet.getLastRow() + 'x' + sheet.getLastColumn();
  const fresh = MEMORY.rows && MEMORY.version === version && Date.now() - MEMORY.at < CONFIG.MEMORY_TTL_MS;

  if (fresh) return MEMORY.rows;

  const values = sheet.getDataRange().getValues();
  if (values.length < 2) throw new Error('Sheet tidak memiliki data.');

  const headers = values[0].map(function (h) {
    return String(h).trim().toLowerCase();
  });

  const idx = {};
  Object.keys(COLUMNS).forEach(function (key) {
    idx[key] = headers.indexOf(COLUMNS[key]);
  });

  const missing = Object.keys(idx)
    .filter(function (key) { return idx[key] === -1; })
    .map(function (key) { return COLUMNS[key]; });

  if (missing.length) {
    throw new Error('Kolom wajib tidak ditemukan: ' + missing.join(', '));
  }

  const rows = [];
  for (let i = 1; i < values.length; i++) {
    const v = values[i];
    const id = toNumber_(v[idx.id]);
    if (id === null) continue;

    const status = toNumber_(v[idx.status]);
    if (status !== 0 && status !== 1) continue;

    rows.push({
      id: id,
      home: toText_(v[idx.home]),
      intent: toText_(v[idx.intent]),
      grade: toText_(v[idx.grade]),
      amount: toNumber_(v[idx.amount]) || 0,
      rate: toNumber_(v[idx.rate]),
      status: status,
      pct: toNumber_(v[idx.pct]),
      band: toText_(v[idx.band]) || 'Unknown'
    });
  }

  MEMORY.rows = rows;
  MEMORY.version = version;
  MEMORY.at = Date.now();
  MEMORY.baseline = null;

  return rows;
}

/* ---------------------------------------------------------------------------
 *  AGREGASI
 * ------------------------------------------------------------------------- */

function buildDashboard_(rows, filters) {
  const current = emptyAccumulator_();
  const needBaseline = !MEMORY.baseline;
  const baselineAcc = MEMORY.baseline || emptyAccumulator_();

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];

    if (needBaseline) addStats_(baselineAcc.total, row);
    if (!matches_(row, filters)) continue;

    addStats_(current.total, row);
    addGroup_(current.grade, row.grade, row);
    addGroup_(current.intent, row.intent, row);

    const tier = dtiTier_(row.pct);
    if (tier) addGroup_(current.dti, tier, row);

    addGroup_(current.matrix, row.home + '|' + row.band, row);
  }

  if (needBaseline) MEMORY.baseline = baselineAcc;

  return {
    filters: {
      grade: filters.grade,
      home: filters.home,
      intent: filters.intent,
      active: filters.grade !== 'ALL' || filters.home !== 'ALL' || filters.intent !== 'ALL'
    },
    kpi: kpiFrom_(current.total),
    baseline: kpiFrom_(baselineAcc.total),
    grade: finalizeOrdered_(current.grade, GRADE_ORDER),
    intent: finalizeOrdered_(current.intent, INTENT_ORDER).sort(function (a, b) {
      return b.rate - a.rate || b.loans - a.loans;
    }),
    dti: finalizeOrdered_(current.dti, DTI_TIERS.map(function (t) { return t.key; })),
    matrix: buildMatrix_(current.matrix),
    options: {
      grades: GRADE_ORDER,
      homes: HOME_ORDER,
      intents: INTENT_ORDER,
      incomeBands: INCOME_ORDER,
      dtiTiers: DTI_TIERS
    },
    coverage: {
      rateMissing: current.total.loans - current.total.rateCount,
      pctMissing: current.total.loans - current.total.pctCount
    }
  };
}

function emptyStats_() {
  return {
    loans: 0,
    defaults: 0,
    amount: 0,
    rateSum: 0,
    rateCount: 0,
    pctSum: 0,
    pctCount: 0,
    highRisk: 0
  };
}

function emptyAccumulator_() {
  return { total: emptyStats_(), grade: {}, intent: {}, dti: {}, matrix: {} };
}

function addStats_(stats, row) {
  stats.loans += 1;
  stats.defaults += row.status;
  stats.amount += row.amount;

  if (row.rate !== null && row.rate > 0) {
    stats.rateSum += row.rate;
    stats.rateCount += 1;
  }

  if (row.pct !== null && isFinite(row.pct)) {
    stats.pctSum += row.pct;
    stats.pctCount += 1;
    if (row.pct >= 0.30) stats.highRisk += 1;
  }
}

function addGroup_(map, key, row) {
  if (!key) return;
  if (!map[key]) map[key] = emptyStats_();
  addStats_(map[key], row);
}

function kpiFrom_(stats) {
  return {
    loans: stats.loans,
    defaults: stats.defaults,
    portfolio: Math.round(stats.amount),
    defaultRate: round2_(stats.loans ? (stats.defaults / stats.loans) * 100 : 0),
    avgRate: round2_(stats.rateCount ? stats.rateSum / stats.rateCount : 0),
    avgLoan: Math.round(stats.loans ? stats.amount / stats.loans : 0),
    avgDti: round2_(stats.pctCount ? (stats.pctSum / stats.pctCount) * 100 : 0),
    highRiskShare: round2_(stats.pctCount ? (stats.highRisk / stats.pctCount) * 100 : 0)
  };
}

function finalizeOrdered_(map, order) {
  return order
    .filter(function (key) { return map[key] && map[key].loans > 0; })
    .map(function (key) {
      const s = map[key];
      return {
        key: key,
        loans: s.loans,
        defaults: s.defaults,
        amount: Math.round(s.amount),
        rate: round2_(s.loans ? (s.defaults / s.loans) * 100 : 0)
      };
    });
}

function buildMatrix_(map) {
  const homes = [];
  const bands = [];

  const cells = [];
  const keys = Object.keys(map);

  keys.forEach(function (key) {
    const parts = key.split('|');
    const home = parts[0];
    const band = parts[1];
    if (homes.indexOf(home) === -1) homes.push(home);
    if (bands.indexOf(band) === -1) bands.push(band);

    const s = map[key];
    cells.push({
      home: home,
      band: band,
      loans: s.loans,
      defaults: s.defaults,
      rate: round2_(s.loans ? (s.defaults / s.loans) * 100 : 0)
    });
  });

  return {
    homes: HOME_ORDER.filter(function (h) { return homes.indexOf(h) !== -1; })
      .concat(homes.filter(function (h) { return HOME_ORDER.indexOf(h) === -1; }).sort()),
    bands: INCOME_ORDER.filter(function (b) { return bands.indexOf(b) !== -1; })
      .concat(bands.filter(function (b) { return INCOME_ORDER.indexOf(b) === -1; }).sort()),
    cells: cells
  };
}

/* ---------------------------------------------------------------------------
 *  FILTER & UTIL
 * ------------------------------------------------------------------------- */

function normalizeFilters_(raw) {
  const input = raw || {};
  return {
    grade: normalizeValue_(input.grade),
    home: normalizeValue_(input.home),
    intent: normalizeValue_(input.intent)
  };
}

function normalizeValue_(value) {
  if (value === null || value === undefined) return 'ALL';
  const text = String(value).trim().toUpperCase();
  return text === '' || text === 'ALL' ? 'ALL' : text;
}

function matches_(row, filters) {
  if (filters.grade !== 'ALL' && row.grade !== filters.grade) return false;
  if (filters.home !== 'ALL' && row.home !== filters.home) return false;
  if (filters.intent !== 'ALL' && row.intent !== filters.intent) return false;
  return true;
}

function dtiTier_(pct) {
  if (pct === null || !isFinite(pct) || pct < 0) return null;
  if (pct < 0.10) return '<10%';
  if (pct < 0.20) return '10-19%';
  if (pct < 0.30) return '20-29%';
  if (pct < 0.40) return '30-39%';
  return '40%+';
}

function toNumber_(value) {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value === 'number') return isFinite(value) ? value : null;
  const parsed = parseFloat(String(value).trim().replace(',', '.'));
  return isFinite(parsed) ? parsed : null;
}

function toText_(value) {
  return value === null || value === undefined ? '' : String(value).trim().toUpperCase();
}

function round2_(value) {
  return Math.round(value * 100) / 100;
}

