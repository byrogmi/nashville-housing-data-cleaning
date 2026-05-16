/*
===============================================================================
DATA CLEANING PORTFOLIO PROJECT: NASHVILLE HOUSING
===============================================================================
Author: Roger
Database Dialect: MySQL
Description: Professional data cleaning pipeline converting raw, unformatted 
             housing market data into a production-ready analytical dataset.
===============================================================================
*/

SELECT *
FROM SQLTuturial.NashvilleHousing nh;

-- ===============================================================================
-- 1. STANDARDIZE DATE FORMAT
-- ===============================================================================

-- 1. TEST: Check transformation before applying
SELECT 
    SaleDate, 
    STR_TO_DATE(SaleDate, '%M %e, %Y') AS SaleDateConverted
FROM SQLTuturial.NashvilleHousing nh;

-- 2. STRUCTURE: Add new column
ALTER TABLE SQLTuturial.NashvilleHousing
ADD SaleDateConverted DATE;

-- 3. EXECUTION: Fill the new column
UPDATE SQLTuturial.NashvilleHousing
SET SaleDateConverted = STR_TO_DATE(SaleDate, '%M %e, %Y');

-- 4. VERIFICATION: Validate correct format (YYYY-MM-DD)
SELECT SaleDate, SaleDateConverted 
FROM SQLTuturial.NashvilleHousing
LIMIT 10;

/*
  [EN] TECHNICAL INSIGHT: MySQL requires specific format identifiers inside STR_TO_DATE() 
       to parse textual dates into a standardized ISO date. 
       DESIGN DECISION: Added a new column instead of overwriting the raw data to 
       maintain data integrity and enable seamless validation.
  [DE] TECHNISCHER EINBLICK: MySQL benötigt spezifische Format-Identifikatoren in STR_TO_DATE(),
       um Text-Daten in ein ISO-Standard-Datum zu konvertieren.
       ARCHITEKTUR-ENTSCHEIDUNG: Eine neue Spalte wurde hinzugefügt, anstatt die Rohdaten 
       zu überschreiben, um die Datenintegrität für spätere Validierungen zu wahren.
*/

-- ===============================================================================
-- 2. POPULATE MISSING PROPERTY ADDRESS DATA
-- ===============================================================================

-- Find missing values and their counterparts based on identical ParcelID
SELECT
    a.ParcelID, a.PropertyAddress,
    b.ParcelID, b.PropertyAddress,
    IFNULL(a.PropertyAddress, b.PropertyAddress)
FROM SQLTuturial.NashvilleHousing a
JOIN SQLTuturial.NashvilleHousing b
    ON a.ParcelID = b.ParcelID
    AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL;

-- Execute the Self-Join Update
UPDATE SQLTuturial.NashvilleHousing a
JOIN SQLTuturial.NashvilleHousing b
    ON a.ParcelID = b.ParcelID
    AND a.UniqueID <> b.UniqueID
SET a.PropertyAddress = IFNULL(a.PropertyAddress, b.PropertyAddress)
WHERE a.PropertyAddress IS NULL;

-- Verify results (Should return 0)
SELECT COUNT(*) 
FROM SQLTuturial.NashvilleHousing 
WHERE PropertyAddress IS NULL;

/*
  [EN] BUSINESS IMPACT: Utilized a Self-Join to automatically populate missing addresses 
       by linking matching ParcelIDs. This preserves critical geospatial data points, 
       essential for downstream regional pricing analyses.
  [DE] BUSINESS IMPACT: Nutzung eines Self-Joins, um fehlende Adressen über identische 
       ParcelIDs zu rekonstruieren. Dies rettet wertvolle Geodaten, die für spätere 
       regionale Preisanalysen essenziell sind.
*/

-- ===============================================================================
-- 3. BREAKING OUT PROPERTY ADDRESS INTO INDIVIDUAL COLUMNS (HouseNumber, Street, City)
-- ===============================================================================

-- Test regex-like string parsing logic
SELECT
    PropertyAddress,
    TRIM(SUBSTRING_INDEX(PropertyAddress, ' ', 1)) AS HouseNumber,
    TRIM(SUBSTR(SUBSTRING_INDEX(PropertyAddress, ',', 1), LOCATE(' ', PropertyAddress) + 1)) AS Street,
    TRIM(SUBSTRING_INDEX(PropertyAddress, ',', -1)) AS City   
FROM SQLTuturial.NashvilleHousing nh;

-- Structural implementation
ALTER TABLE SQLTuturial.NashvilleHousing
ADD PropertySplitHouseNumber NVARCHAR(255),
ADD PropertySplitStreet NVARCHAR(255),
ADD PropertySplitCity NVARCHAR(255);

-- Update target columns
UPDATE SQLTuturial.NashvilleHousing
SET 
    PropertySplitHouseNumber = TRIM(SUBSTRING_INDEX(PropertyAddress, ' ', 1)),
    PropertySplitStreet = TRIM(SUBSTR(SUBSTRING_INDEX(PropertyAddress, ',', 1), LOCATE(' ', PropertyAddress) + 1)),
    PropertySplitCity = TRIM(SUBSTRING_INDEX(PropertyAddress, ',', -1));

/*
  [EN] EXTRA MILE & PORTFOLIO HIGHLIGHT: Extracted the house number into a dedicated column. 
       This extends beyond the standard tutorial scope and is crucial for granular 
       geocoding and spatial analytics.
       DIALECT ADAPTATION: Since MySQL lacks 'PARSENAME', I engineered a robust solution 
       using nested SUBSTRING_INDEX and LOCATE functions.
  [DE] EXTRA MILE HIGHLIGHT: Die Hausnummer wurde separat extrahiert. Dies geht über das 
       standardmäßige Tutorial hinaus und ist entscheidend für präzise Geokodierung.
       DIALEKT-ANPASSUNG: Da MySQL keine 'PARSENAME'-Funktion besitzt, wurde eine robuste 
       Verschachtelung aus SUBSTRING_INDEX und LOCATE entwickelt.
*/

-- ===============================================================================
-- 4. BREAKING OUT OWNER ADDRESS (HouseNumber, Street, City, State)
-- ===============================================================================

ALTER TABLE SQLTuturial.NashvilleHousing
ADD OwnerSplitHouseNumber NVARCHAR(255),
ADD OwnerSplitStreet NVARCHAR(255),
ADD OwnerSplitCity NVARCHAR(255),
ADD OwnerSplitState NVARCHAR(255);

UPDATE SQLTuturial.NashvilleHousing nh
SET
    OwnerSplitHouseNumber = TRIM(SUBSTRING_INDEX(nh.OwnerAddress, ' ', 1)),
    OwnerSplitStreet = TRIM(SUBSTRING(SUBSTRING_INDEX(nh.OwnerAddress, ',', 1), LOCATE(' ', nh.OwnerAddress) + 1)),
    OwnerSplitCity = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(nh.OwnerAddress, ',', 2), ',', -1)),
    OwnerSplitState = TRIM(SUBSTRING_INDEX(nh.OwnerAddress, ',', -1));

/*
  [EN] DATA CLEANING BEST PRACTICE: Consistent application of TRIM() prevents trailing 
       or leading whitespaces from corrupting future JOIN operations or BI dashboards.
  [DE] BEST PRACTICE: Konsequente Nutzung von TRIM(), um unsichtbare Leerzeichen zu 
       verhindern, die zukünftige JOIN-Operationen oder BI-Dashboards verfälschen könnten.
*/

-- ===============================================================================
-- 5. STANDARDIZE "SOLD AS VACANT" FIELD (Y/N to Yes/No)
-- ===============================================================================

-- Audit column status
SELECT DISTINCT(nh.SoldAsVacant), COUNT(nh.SoldAsVacant)
FROM SQLTuturial.NashvilleHousing nh
GROUP BY nh.SoldAsVacant
ORDER BY 2;

-- Apply standardizing conditional logic
UPDATE SQLTuturial.NashvilleHousing
SET SoldAsVacant = CASE 
    WHEN SoldAsVacant = 'Y' THEN 'Yes'
    WHEN SoldAsVacant = 'N' THEN 'No'
    ELSE SoldAsVacant 
END;

/*
  [EN] BI READINESS: Standardized categorical mixed values ("Y"/"Yes"). Algorithms 
       and BI tools (Tableau/PowerBI) treat "Y" and "Yes" as distinct categories. 
       Unifying them guarantees accurate categorical aggregation.
  [DE] BI-BEREITSCHAFT: Vereinheitlichung von Mischwerten ("Y"/"Yes"). Machine Learning 
       Modelle und BI-Tools behandeln diese als unterschiedliche Kategorien. Die 
       Harmonisierung sichert korrekte Aggregationen.
*/

-- ===============================================================================
-- 6. DYNAMIC DUPLICATE FILTERING & PRODUCTION DEPLOYMENT (VIEW)
-- ===============================================================================

CREATE OR REPLACE VIEW SQLTuturial.CleanNashvilleHousing AS
WITH RowNumCTE AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                nh.ParcelID,
                nh.PropertyAddress,
                nh.SalePrice,
                nh.SaleDate,
                nh.LegalReference
            ORDER BY
                nh.UniqueID
        ) as row_num
    FROM SQLTuturial.NashvilleHousing nh
)
SELECT 
    UniqueID,
    ParcelID,
    LandUse,
    SaleDateConverted,
    SalePrice,
    LegalReference,
    SoldAsVacant,
    PropertySplitHouseNumber,
    PropertySplitStreet,
    PropertySplitCity,
    OwnerSplitHouseNumber,
    OwnerSplitStreet,
    OwnerSplitCity,
    OwnerSplitState
FROM RowNumCTE 
WHERE row_num = 1;

-- Final Verification of the analytical layer
SELECT * FROM SQLTuturial.CleanNashvilleHousing;

/*
  [EN] ARCHITECTURAL DECISION: Instead of hard-deleting records or 
       dropping columns from raw tables (which threatens data lineage), duplicates 
       and redundant columns are programmatically omitted inside a dynamic VIEW.
       ADVANTAGE: The source data remains secure, while BI tools automatically 
       receive a real-time, perfectly cleaned data stream.
  [DE] ARCHITEKTUR-ENTSCHEIDUNG: Anstatt Zeilen oder Spalten permanent 
       aus den Rohdaten zu löschen (Gefahr für Data Lineage), werden Duplikate 
       und ungenutzte Spalten über eine dynamische VIEW ausgeblendet.
       VORTEIL: Die Rohdaten bleiben unangetastet, während BI-Tools vollautomatisch 
       auf einen perfekt bereinigten Echtzeit-Datenstrom zugreifen.
*/

