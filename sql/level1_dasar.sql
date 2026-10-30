-- ====================================================================
-- LEVEL 1: SQL DASAR (SELECT, WHERE, GROUP BY, AGREGAT)
-- Dataset: credit_risk (SQLite)
-- Total baris terverifikasi: 32.409
-- ====================================================================

-- 1. Ringkasan Keseluruhan Portofolio Pinjaman
-- Target angka terverifikasi:
-- Total pinjaman: 32.409 | Total volume: ~310.88M | Rata-rata pinjaman: 9.592
-- Rata-rata suku bunga: 11,02% | Gagal bayar: 7.088 (21,9%)
SELECT 
    COUNT(*) AS total_loans,
    SUM(loan_amnt) AS total_loan_amount,
    ROUND(AVG(loan_amnt), 2) AS avg_loan_amount,
    ROUND(AVG(loan_int_rate), 2) AS avg_int_rate,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM credit_risk;


-- 2. Pertanyaan Bisnis 1: Persentase Gagal Bayar per Loan Grade
-- Target angka terverifikasi:
-- A: 10,0% | B: 16,3% | C: 20,8% | D: 59,0% | E: 64,5% | F: 70,5% | G: 98,4%
SELECT 
    loan_grade,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM credit_risk
GROUP BY loan_grade
ORDER BY loan_grade;


-- 3. Pertanyaan Bisnis 2: Persentase Gagal Bayar per Tujuan Pinjaman (Loan Intent)
-- Target angka terverifikasi:
-- DEBTCONSOLIDATION: 28,7% | MEDICAL: 26,8% | HOMEIMPROVEMENT: 26,2%
-- PERSONAL: 19,9% | EDUCATION: 17,3% | VENTURE: 14,9%
SELECT 
    loan_intent,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM credit_risk
GROUP BY loan_intent
ORDER BY default_rate_pct DESC;


-- 4. Pertanyaan Bisnis 3: Persentase Gagal Bayar per Status Kepemilikan Rumah (Home Ownership)
-- Target angka terverifikasi:
-- RENT: 31,6% | OTHER: 31,1% | MORTGAGE: 12,6% | OWN: 7,5%
SELECT 
    person_home_ownership,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS total_defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM credit_risk
GROUP BY person_home_ownership
ORDER BY default_rate_pct DESC;