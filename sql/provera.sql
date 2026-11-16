--test--
SELECT competition_id, season, COUNT(*) AS broj_utakmica
FROM stg.games
GROUP BY competition_id, season
ORDER BY competition_id, season;

select club_id as "ID_Como",name from stg.clubs 
where club_code like '%como%'

SELECT
    SUM(CASE WHEN transfer_fee IS NULL THEN 1 ELSE 0 END) AS nepoznat_iznos,
    SUM(CASE WHEN transfer_fee = 0     THEN 1 ELSE 0 END) AS slobodan_transfer,
    SUM(CASE WHEN transfer_fee > 0     THEN 1 ELSE 0 END) AS placen_transfer
FROM stg.transfers;

select count(*) from stg.transfers
where transfer_date > '2026-07-06'

SELECT COUNT(*) AS transferi_bez_kluba
FROM stg.transfers t
LEFT JOIN stg.clubs c ON c.club_id = t.to_club_id
WHERE c.club_id IS NULL;

