-- Connect to moex_dwh database
\c moex_dwh;

-- Create schema for analytics
CREATE SCHEMA IF NOT EXISTS analytics;

-- Dimension: Date
CREATE TABLE IF NOT EXISTS analytics.dim_date (
    date_key INTEGER PRIMARY KEY,
    date DATE UNIQUE NOT NULL,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    month INTEGER NOT NULL,
    week INTEGER NOT NULL,
    day INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    is_holiday BOOLEAN DEFAULT FALSE
);

-- Dimension: Securities
CREATE TABLE IF NOT EXISTS analytics.dim_security (
    security_key SERIAL PRIMARY KEY,
    secid VARCHAR(50) UNIQUE NOT NULL,
    shortname VARCHAR(255),
    sectypename VARCHAR(255),
    boardname VARCHAR(255),
    lotsize INTEGER,
    facevalue DECIMAL(18, 4),
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP DEFAULT '9999-12-31',
    is_current BOOLEAN DEFAULT TRUE
);

-- Fact: Daily Trading
CREATE TABLE IF NOT EXISTS analytics.fact_daily_trading (
    trading_key SERIAL PRIMARY KEY,
    date_key INTEGER REFERENCES analytics.dim_date(date_key),
    security_key INTEGER REFERENCES analytics.dim_security(security_key),
    open_price DECIMAL(18, 4),
    close_price DECIMAL(18, 4),
    high_price DECIMAL(18, 4),
    low_price DECIMAL(18, 4),
    volume BIGINT,
    value DECIMAL(18, 2),
    num_trades INTEGER,
    price_change DECIMAL(18, 4),
    price_change_pct DECIMAL(10, 4),
    volatility DECIMAL(10, 4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(date_key, security_key)
);

-- Aggregate: Weekly Trading
CREATE TABLE IF NOT EXISTS analytics.agg_weekly_trading (
    week_key INTEGER,
    security_key INTEGER REFERENCES analytics.dim_security(security_key),
    year INTEGER,
    week_num INTEGER,
    week_start_date DATE,
    week_end_date DATE,
    open_price DECIMAL(18, 4),
    close_price DECIMAL(18, 4),
    high_price DECIMAL(18, 4),
    low_price DECIMAL(18, 4),
    avg_price DECIMAL(18, 4),
    total_volume BIGINT,
    total_value DECIMAL(18, 2),
    total_trades INTEGER,
    price_change DECIMAL(18, 4),
    price_change_pct DECIMAL(10, 4),
    avg_volatility DECIMAL(10, 4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(week_key, security_key)
);

-- Aggregate: Monthly Trading
CREATE TABLE IF NOT EXISTS analytics.agg_monthly_trading (
    month_key INTEGER,
    security_key INTEGER REFERENCES analytics.dim_security(security_key),
    year INTEGER,
    month INTEGER,
    month_start_date DATE,
    month_end_date DATE,
    open_price DECIMAL(18, 4),
    close_price DECIMAL(18, 4),
    high_price DECIMAL(18, 4),
    low_price DECIMAL(18, 4),
    avg_price DECIMAL(18, 4),
    total_volume BIGINT,
    total_value DECIMAL(18, 2),
    total_trades INTEGER,
    price_change DECIMAL(18, 4),
    price_change_pct DECIMAL(10, 4),
    avg_volatility DECIMAL(10, 4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(month_key, security_key)
);

-- Analytics: Top Performers
CREATE TABLE IF NOT EXISTS analytics.top_performers (
    analysis_date DATE,
    period VARCHAR(20), -- 'daily', 'weekly', 'monthly'
    security_key INTEGER REFERENCES analytics.dim_security(security_key),
    rank INTEGER,
    price_change_pct DECIMAL(10, 4),
    volume BIGINT,
    value DECIMAL(18, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(analysis_date, period, security_key)
);

-- Analytics: Market Summary
CREATE TABLE IF NOT EXISTS analytics.market_summary (
    summary_date DATE PRIMARY KEY,
    total_securities INTEGER,
    total_volume BIGINT,
    total_value DECIMAL(18, 2),
    total_trades INTEGER,
    avg_price_change_pct DECIMAL(10, 4),
    gainers_count INTEGER,
    losers_count INTEGER,
    unchanged_count INTEGER,
    market_volatility DECIMAL(10, 4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_fact_daily_trading_date ON analytics.fact_daily_trading(date_key);
CREATE INDEX idx_fact_daily_trading_security ON analytics.fact_daily_trading(security_key);

CREATE INDEX idx_agg_weekly_security ON analytics.agg_weekly_trading(security_key);
CREATE INDEX idx_agg_weekly_year_week ON analytics.agg_weekly_trading(year, week_num);

CREATE INDEX idx_agg_monthly_security ON analytics.agg_monthly_trading(security_key);
CREATE INDEX idx_agg_monthly_year_month ON analytics.agg_monthly_trading(year, month);

CREATE INDEX idx_top_performers_date ON analytics.top_performers(analysis_date);
CREATE INDEX idx_top_performers_period ON analytics.top_performers(period);

CREATE INDEX idx_dim_security_secid ON analytics.dim_security(secid);

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA analytics TO moex_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics TO moex_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA analytics TO moex_user;
