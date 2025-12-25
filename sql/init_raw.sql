-- Create Airflow database
CREATE DATABASE airflow;

-- Connect to moex_raw database
\c moex_raw;

-- Create schema for raw data
CREATE SCHEMA IF NOT EXISTS raw_data;

-- Table for raw stock data
CREATE TABLE IF NOT EXISTS raw_data.stocks (
    id SERIAL PRIMARY KEY,
    secid VARCHAR(50) NOT NULL,
    boardid VARCHAR(10),
    shortname VARCHAR(255),
    prevprice DECIMAL(18, 4),
    lotsize INTEGER,
    facevalue DECIMAL(18, 4),
    status VARCHAR(50),
    boardname VARCHAR(255),
    decimals INTEGER,
    sectypename VARCHAR(255),
    remarks VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for trading history
CREATE TABLE IF NOT EXISTS raw_data.trade_history (
    id SERIAL PRIMARY KEY,
    secid VARCHAR(50) NOT NULL,
    tradedate DATE NOT NULL,
    open DECIMAL(18, 4),
    low DECIMAL(18, 4),
    high DECIMAL(18, 4),
    close DECIMAL(18, 4),
    volume BIGINT,
    value DECIMAL(18, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(secid, tradedate)
);

-- Table for market data snapshots
CREATE TABLE IF NOT EXISTS raw_data.market_data (
    id SERIAL PRIMARY KEY,
    secid VARCHAR(50) NOT NULL,
    boardid VARCHAR(10),
    bid DECIMAL(18, 4),
    offer DECIMAL(18, 4),
    spread DECIMAL(18, 4),
    biddepth INTEGER,
    offerdepth INTEGER,
    biddeptht BIGINT,
    offerdeptht BIGINT,
    last DECIMAL(18, 4),
    lastchange DECIMAL(18, 4),
    lastchangeprcnt DECIMAL(10, 4),
    qty INTEGER,
    value DECIMAL(18, 2),
    value_usd DECIMAL(18, 2),
    waprice DECIMAL(18, 4),
    numtrades INTEGER,
    voltoday BIGINT,
    valtoday DECIMAL(18, 2),
    valtoday_usd DECIMAL(18, 2),
    tradingstatus VARCHAR(50),
    timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for ETL job logs
CREATE TABLE IF NOT EXISTS raw_data.etl_logs (
    id SERIAL PRIMARY KEY,
    job_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    records_processed INTEGER,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_trade_history_secid ON raw_data.trade_history(secid);
CREATE INDEX idx_trade_history_tradedate ON raw_data.trade_history(tradedate);
CREATE INDEX idx_trade_history_secid_date ON raw_data.trade_history(secid, tradedate);

CREATE INDEX idx_market_data_secid ON raw_data.market_data(secid);
CREATE INDEX idx_market_data_timestamp ON raw_data.market_data(timestamp);
CREATE INDEX idx_market_data_secid_timestamp ON raw_data.market_data(secid, timestamp);

CREATE INDEX idx_stocks_secid ON raw_data.stocks(secid);

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA raw_data TO moex_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA raw_data TO moex_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA raw_data TO moex_user;
