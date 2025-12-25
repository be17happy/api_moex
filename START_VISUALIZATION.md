#  Запуск визуализации - Быстрая инструкция

### ШАГ 1: Откройте Grafana

В браузере: **http://localhost:3000**

```
Логин: admin
Пароль: admin
```

(При первом входе может попросить сменить пароль - нажмите "Skip")

---

### ШАГ 2: Создайте новый дашборд

1. Нажмите **➕** (плюс) в левом меню
2. Выберите **"Dashboard"**
3. Нажмите **"Add visualization"**
4. Выберите **"MOEX Analytics DWH"** (если нет - см. раздел "Настройка" ниже)

---

### ШАГ 3: Создайте первый график

**Скопируйте этот SQL запрос:**

```sql
SELECT
  summary_date as time,
  total_volume as "Объем торгов",
  total_value as "Стоимость сделок"
FROM analytics.market_summary
ORDER BY summary_date
```

**Где вставить:**
1. Внизу экрана переключите с "Builder" на **"Code"** (переключатель справа)
2. Вставьте SQL запрос
3. В правой панели:
   - **Title:** "Объем и стоимость торгов"
   - **Visualization:** Time series
4. Нажмите **"Apply"** (вверху справа)

---

##  Готовые SQL запросы для дашборда

### График 1: Объем торгов
```sql
SELECT summary_date as time, total_volume as value
FROM analytics.market_summary
ORDER BY summary_date
```

### График 2: Изменение цен
```sql
SELECT summary_date as time, avg_price_change_pct as value
FROM analytics.market_summary
ORDER BY summary_date
```

### График 3: Gainers vs Losers
```sql
SELECT
  summary_date as time,
  gainers_count as "Растут",
  losers_count as "Падают"
FROM analytics.market_summary
ORDER BY summary_date
```

### График 4: Топ акций
```sql
SELECT
  s.secid as "Тикер",
  ROUND(AVG(f.price_change_pct)::numeric, 2) as "Изм. %"
FROM analytics.fact_daily_trading f
JOIN analytics.dim_security s ON f.security_key = s.security_key
GROUP BY s.secid
ORDER BY AVG(f.price_change_pct) DESC
LIMIT 10
```

### График 5: Волатильность
```sql
SELECT summary_date as time, market_volatility as value
FROM analytics.market_summary
ORDER BY summary_date
```


**Полная документация:** см. файл `VISUALIZATION_GUIDE.md`
