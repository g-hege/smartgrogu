drop view public.consumption_epex_price cascade;
drop view public.energy_last_30_days cascade;
drop view public.energy_monthly_spotty cascade;
drop view public.energy_monthly_statistik cascade;
drop view public.energy_monthly_statistik_price cascade;
drop view public.energy_spotty_last_30_days cascade;
drop view public.energy_yearly_statistik cascade;
drop view public.solarweek cascade;

CREATE OR REPLACE VIEW public.consumption_epex_price
AS SELECT c.device,
    c."timestamp",
    c.value,
    epex.marketprice,
    c.value::numeric * (epex.marketprice / 1000000::numeric) AS price
   FROM consumption c
     JOIN epex ON c."timestamp" = epex."timestamp";



-- public.energy_last_30_days source

CREATE OR REPLACE VIEW public.energy_last_30_days
AS SELECT to_char(date_trunc('day'::text, consumption."timestamp"), 'yyyy-mm-dd'::text) AS day,
    sum(
        CASE
            WHEN consumption.device = 'wienstrom'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS wienstrom,
    sum(
        CASE
            WHEN consumption.device = 'solar'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS solarenergie,
    sum(
        CASE
            WHEN consumption.device = 'boiler'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS boiler,
    sum(
        CASE
            WHEN consumption.device = 'tv'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS tv,
    sum(
        CASE
            WHEN consumption.device = 'workplace'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS workplace,
    sum(
        CASE
            WHEN consumption.device = 'fridge1'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS fridge1,
    sum(
        CASE
            WHEN consumption.device = 'fridge2'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS fridge2,
    sum(
        CASE
            WHEN consumption.device = 'waschmaschine'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS waschmaschine,
    sum(
        CASE
            WHEN consumption.device = 'trocker'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS trocker,
    sum(
        CASE
            WHEN consumption.device = 'pool'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS pool,
    sum(
        CASE
            WHEN consumption.device = 'plug'::text THEN consumption.value::numeric
            ELSE 0::numeric
        END)::double precision AS plug
   FROM consumption
  WHERE consumption."timestamp" > (CURRENT_DATE - '31 days'::interval)
  GROUP BY (date_trunc('day'::text, consumption."timestamp"))
  ORDER BY (date_trunc('day'::text, consumption."timestamp"));

-- Permissions

ALTER TABLE public.energy_last_30_days OWNER TO postgres;
GRANT ALL ON TABLE public.energy_last_30_days TO postgres;


-- public.energy_monthly_spotty source

CREATE OR REPLACE VIEW public.energy_monthly_spotty
AS SELECT to_char(date_trunc('month'::text, consumption_epex_price."timestamp"), 'yyyy-mm'::text) AS month,
    sum(consumption_epex_price.value) AS wienstrom,
    sum(consumption_epex_price.price) * 1.2 AS energie,
    (sum(consumption_epex_price.value) / 1000)::numeric * 0.0149 * 1.2 AS service_fee,
    0.0667 * 30::numeric * 1.2 AS grundgebuer,
    (sum(consumption_epex_price.value) / 1000)::numeric * 0.003 * 1.2 AS stomherkunftsnachweise,
    ((sum(consumption_epex_price.value) / 1000)::numeric * 0.062 + 8::numeric) * 1.2 AS netznutzung,
    sum(consumption_epex_price.price) * 1.2 + (sum(consumption_epex_price.value) / 1000)::numeric * 0.0149 * 1.2 + 0.0667 * 30::numeric * 1.2 + (sum(consumption_epex_price.value) / 1000)::numeric * 0.003 * 1.2 AS spotty,
    sum(consumption_epex_price.price) * 1.2 + (sum(consumption_epex_price.value) / 1000)::numeric * 0.0149 * 1.2 + 0.0667 * 30::numeric * 1.2 + (sum(consumption_epex_price.value) / 1000)::numeric * 0.003 * 1.2 + ((sum(consumption_epex_price.value) / 1000)::numeric * 0.062 + 8::numeric) * 1.2 AS gesamt
   FROM consumption_epex_price
  WHERE consumption_epex_price.device = 'wienstrom'::text
  GROUP BY (date_trunc('month'::text, consumption_epex_price."timestamp"))
  ORDER BY (date_trunc('month'::text, consumption_epex_price."timestamp"));



-- public.energy_monthly_statistik source

CREATE OR REPLACE VIEW public.energy_monthly_statistik
AS SELECT to_char(date_trunc('month'::text, consumption."timestamp"), 'yyyy-mm'::text) AS month,
    sum(
        CASE
            WHEN consumption.device = 'wienstrom'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS wienstrom,
    sum(
        CASE
            WHEN consumption.device = 'solar'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS solarenergie,
    sum(
        CASE
            WHEN consumption.device = 'boiler'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS boiler,
    sum(
        CASE
            WHEN consumption.device = 'tv'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS tv,
    sum(
        CASE
            WHEN consumption.device = 'workplace'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS workplace,
    sum(
        CASE
            WHEN consumption.device = 'fridge1'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS fridge1,
    sum(
        CASE
            WHEN consumption.device = 'fridge2'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS fridge2,
    sum(
        CASE
            WHEN consumption.device = 'waschmaschine'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS waschmaschine,
    sum(
        CASE
            WHEN consumption.device = 'trocker'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS trocker,
    sum(
        CASE
            WHEN consumption.device = 'pool'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS pool,
    sum(
        CASE
            WHEN consumption.device = 'plug'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS plug
   FROM consumption
  GROUP BY (date_trunc('month'::text, consumption."timestamp"))
  ORDER BY (date_trunc('month'::text, consumption."timestamp"));




-- public.energy_monthly_statistik_price source

CREATE OR REPLACE VIEW public.energy_monthly_statistik_price
AS SELECT to_char(date_trunc('month'::text, consumption_epex_price."timestamp"), 'yyyy-mm'::text) AS month,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'wienstrom'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS wienstrom,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'solar'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS solarenergie,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'boiler'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS boiler,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'tv'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS tv,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'workplace'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS workplace,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'fridge1'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS fridge1,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'fridge2'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS fridge2,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'waschmaschine'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS waschmaschine,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'trocker'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS trocker,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'pool'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS pool,
    sum(
        CASE
            WHEN consumption_epex_price.device = 'plug'::text THEN consumption_epex_price.price
            ELSE 0::numeric
        END)::double precision AS plug
   FROM consumption_epex_price
  GROUP BY (date_trunc('month'::text, consumption_epex_price."timestamp"))
  ORDER BY (date_trunc('month'::text, consumption_epex_price."timestamp"));



CREATE OR REPLACE VIEW public.energy_spotty_last_30_days
AS SELECT to_char(date_trunc('day'::text, consumption_epex_price."timestamp"), 'yyyy-mm-dd'::text) AS day,
    sum(consumption_epex_price.value) AS wienstrom,
    sum(consumption_epex_price.price) AS epex_price,
    (sum(consumption_epex_price.value) / 1000)::numeric * 0.0036 AS energie_preis,
    (sum(consumption_epex_price.value) / 1000)::numeric * 0.003 AS stromherkunftsnachweise,
    sum(consumption_epex_price.price) + (sum(consumption_epex_price.value) / 1000)::numeric * 0.0036 + (sum(consumption_epex_price.value) / 1000)::numeric * 0.00036 AS netto,
    (sum(consumption_epex_price.price) + (sum(consumption_epex_price.value) / 1000)::numeric * 0.0036 + (sum(consumption_epex_price.value) / 1000)::numeric * 0.00036) * 1.2 AS brutto
   FROM consumption_epex_price
  WHERE consumption_epex_price.device = 'wienstrom'::text AND consumption_epex_price."timestamp" > (CURRENT_DATE - '30 days'::interval)
  GROUP BY (date_trunc('day'::text, consumption_epex_price."timestamp"))
  ORDER BY (date_trunc('day'::text, consumption_epex_price."timestamp"));



CREATE OR REPLACE VIEW public.energy_yearly_statistik
AS SELECT to_char(date_trunc('year'::text, consumption."timestamp"), 'yyyy'::text) AS year,
    sum(
        CASE
            WHEN consumption.device = 'wienstrom'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS wienstrom,
    sum(
        CASE
            WHEN consumption.device = 'solar'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS solarenergie,
    sum(
        CASE
            WHEN consumption.device = 'boiler'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS boiler,
    sum(
        CASE
            WHEN consumption.device = 'tv'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS tv,
    sum(
        CASE
            WHEN consumption.device = 'workplace'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS workplace,
    sum(
        CASE
            WHEN consumption.device = 'fridge1'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS fridge1,
    sum(
        CASE
            WHEN consumption.device = 'fridge2'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS fridge2,
    sum(
        CASE
            WHEN consumption.device = 'waschmaschine'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS waschmaschine,
    sum(
        CASE
            WHEN consumption.device = 'trocker'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS trocker,
    sum(
        CASE
            WHEN consumption.device = 'pool'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS pool,
    sum(
        CASE
            WHEN consumption.device = 'plug'::text THEN consumption.value
            ELSE 0
        END)::double precision / 1000::double precision AS plug
   FROM consumption
  GROUP BY (date_trunc('year'::text, consumption."timestamp"))
  ORDER BY (date_trunc('year'::text, consumption."timestamp"));



CREATE OR REPLACE VIEW public.solarweek
AS SELECT to_char(date_trunc('day'::text, consumption."timestamp"), 'yyyy-mm-dd'::text) AS day,
    sum(consumption.value) AS solarenergie
   FROM consumption
  WHERE consumption."timestamp" > (CURRENT_DATE - '6 days'::interval) AND consumption.device = 'solar'::text
  GROUP BY (date_trunc('day'::text, consumption."timestamp"))
  ORDER BY (date_trunc('day'::text, consumption."timestamp"));



