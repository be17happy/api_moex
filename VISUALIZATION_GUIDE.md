# Руководство по запуску визуализации

## ✅ Данные готовы!

```
✓ dim_security: 20 записей
✓ dim_date: 23 записей
✓ fact_daily_trading: 460 записей
✓ market_summary: 23 записей
```

## 🎨 Шаг 1: Откройте Grafana

```bash
open http://localhost:3000
```

Или в браузере: http://localhost:3000

**Логин:** `admin`
**Пароль:** `admin`

При первом входе может попросить сменить пароль - можно нажать "Skip".

## 📊 Шаг 2: Проверьте подключение к базе данных

1. В левом меню нажмите **⚙️ Configuration** → **Data Sources**
2. Должен быть источник **"MOEX Analytics DWH"**
3. Нажмите на него
4. Внизу нажмите **"Test"** - должно быть "Database Connection OK"

Если источника нет, создайте:
- Click **"Add data source"**
- Выберите **PostgreSQL**
- Настройки:
  - **Name:** `MOEX Analytics DWH`
  - **Host:** `postgres_dwh:5432`
  - **Database:** `moex_dwh`
  - **User:** `moex_user`
  - **Password:** `moex_password`
  - **TLS/SSL Mode:** `disable`
  - **PostgreSQL Version:** `15`
- **Save & Test**

## 📈 Шаг 3: Создайте дашборд вручную

### Вариант A: Простой путь - используйте готовые SQL запросы

#### Панель 1: Общий объем торгов

1. Нажмите **+** → **Dashboard** → **Add visualization**
2. Выберите **MOEX Analytics DWH**
3. В редакторе запросов выберите **Code** (переключатель справа)
4. Вставьте SQL:

```sql
SELECT
  summary_date as time,
  total_volume as value
FROM analytics.market_summary
ORDER BY summary_date
```

5. В правой панели:
   - **Panel Title:** "Total Trading Volume"
   - **Visualization:** Time series
6. **Apply**

#### Панель 2: Средний процент изменения цен

1. **Add** → **Visualization**
2. SQL:

```sql
SELECT
  summary_date as time,
  avg_price_change_pct as value
FROM analytics.market_summary
ORDER BY summary_date
```

3. **Panel Title:** "Average Price Change %"
4. **Visualization:** Time series
5. **Apply**

#### Панель 3: Рыночные настроения (Gainers vs Losers)

1. **Add** → **Visualization**
2. SQL:

```sql
SELECT
  summary_date as time,
  gainers_count as "Gainers",
  losers_count as "Losers"
FROM analytics.market_summary
ORDER BY summary_date
```

3. **Panel Title:** "Market Sentiment"
4. **Visualization:** Time series
5. **Apply**

#### Панель 4: Топ акций по изменению цены

1. **Add** → **Visualization**
2. SQL:

```sql
SELECT
  ds.secid,
  ds.shortname,
  AVG(f.price_change_pct) as avg_change
FROM analytics.fact_daily_trading f
JOIN analytics.dim_security ds ON f.security_key = ds.security_key
GROUP BY ds.secid, ds.shortname
ORDER BY avg_change DESC
LIMIT 10
```

3. **Panel Title:** "Top Performers"
4. **Visualization:** Bar chart или Table
5. **Apply**

#### Панель 5: Волатильность рынка

1. **Add** → **Visualization**
2. SQL:

```sql
SELECT
  summary_date as time,
  market_volatility as value
FROM analytics.market_summary
ORDER BY summary_date
```

3. **Panel Title:** "Market Volatility"
4. **Visualization:** Time series
5. **Apply**

#### Панель 6: Статистика (Stat)

1. **Add** → **Visualization**
2. SQL:

```sql
SELECT
  total_securities as "Active Securities"
FROM analytics.market_summary
ORDER BY summary_date DESC
LIMIT 1
```

3. **Panel Title:** "Active Securities"
4. **Visualization:** Stat
5. **Apply**

### Вариант B: Импорт готового дашборда (если работает)

1. В левом меню: **Dashboards** → **Import**
2. **Upload JSON file**
3. Выберите файл: `dashboards/moex_dashboard.json`
4. Если просит выбрать datasource, выберите **MOEX Analytics DWH**
5. **Import**

## 🎯 Шаг 4: Сохраните дашборд

1. Нажмите **💾 Save dashboard** (вверху справа)
2. Введите имя: **"MOEX Trading Analytics"**
3. **Save**

## 📸 Шаг 5: Сделайте скриншоты для отчета

Откройте дашборд и сделайте скриншоты:

1. **Полный дашборд** - общий вид всех панелей
2. **График объема торгов** - крупным планом
3. **Топ акций** - таблица или график
4. **Рыночные настроения** - gainers vs losers
5. **Статистика** - stat панели

## 🔍 Дополнительные полезные запросы

### Детальная информация по акции

```sql
SELECT
  d.date,
  f.open_price,
  f.close_price,
  f.high_price,
  f.low_price,
  f.volume,
  f.price_change_pct
FROM analytics.fact_daily_trading f
JOIN analytics.dim_date d ON f.date_key = d.date_key
JOIN analytics.dim_security s ON f.security_key = s.security_key
WHERE s.secid = 'НАЗВАНИЕ_АКЦИИ'
ORDER BY d.date
```

### Топ акций за сегодня

```sql
SELECT
  s.secid,
  s.shortname,
  f.close_price,
  f.price_change_pct,
  f.volume
FROM analytics.fact_daily_trading f
JOIN analytics.dim_security s ON f.security_key = s.security_key
JOIN analytics.dim_date d ON f.date_key = d.date_key
WHERE d.date = (SELECT MAX(date) FROM analytics.dim_date)
ORDER BY f.price_change_pct DESC
LIMIT 10
```

### Динамика за период

```sql
SELECT
  d.date as time,
  s.secid as metric,
  f.close_price as value
FROM analytics.fact_daily_trading f
JOIN analytics.dim_date d ON f.date_key = d.date_key
JOIN analytics.dim_security s ON f.security_key = s.security_key
WHERE s.secid IN ('АКЦИЯ1', 'АКЦИЯ2', 'АКЦИЯ3')
ORDER BY d.date, s.secid
```

## 🎨 Настройка внешнего вида

### Для Time Series графиков:
- **Graph styles** → Line width: 2
- **Axis** → Y-axis → Unit: выберите подходящий (currency, percent и т.д.)
- **Legend** → Show legend
- **Tooltip** → Sort order: Descending

### Для таблиц:
- **Table** → Column width: Auto
- **Table** → Show header: On
- **Overrides** → можно настроить форматирование колонок

### Цвета:
- **Standard options** → Color scheme: выберите подходящую палитру
- Для положительных/отрицательных значений используйте Thresholds

## ✅ Чеклист готовности

- [ ] Grafana открывается (http://localhost:3000)
- [ ] Data source подключен и работает
- [ ] Создан хотя бы один дашборд
- [ ] Графики отображают данные
- [ ] Дашборд сохранен
- [ ] Сделаны скриншоты

## 🚀 Готово!

Теперь у вас есть полноценная визуализация данных торгов Московской биржи!

**Для демонстрации:**
1. Откройте дашборд в Grafana
2. Покажите разные графики
3. Объясните метрики
4. Покажите как обновляются данные

**Для отчета:**
- Используйте скриншоты дашбордов
- Опишите какие метрики визуализируете
- Укажите используемые технологии
