-- Add current_period_start and current_period_end to transactions
alter table transactions add column if not exists current_period_start timestamptz;
alter table transactions add column if not exists current_period_end timestamptz;

-- Ensure flutterwave_tx_id exists (it does, but just in case)
alter table transactions add column if not exists flutterwave_tx_id text;
