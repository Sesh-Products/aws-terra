
import os
import json
import pandas as pd
import zipfile
import xml.etree.ElementTree as ET
from io import StringIO, BytesIO
import boto3
import openpyxl
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.backends import default_backend
import snowflake.connector
from cryptography.hazmat.primitives.serialization import Encoding, PrivateFormat, NoEncryption


s3 = boto3.client("s3")
ses_client = boto3.client("ses", region_name="us-east-1")

VENDOR_CONFIG = json.loads(os.environ.get("VENDOR_CONFIG", "{}"))
COLUMN_CONFIG = json.loads(os.environ.get("COLUMN_CONFIG", "{}"))
SNOWFLAKE_ACCOUNT   = os.environ.get("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_USER      = os.environ.get("SNOWFLAKE_USER")
SNOWFLAKE_DATABASE  = os.environ.get("SNOWFLAKE_DATABASE", "SESH_METADATA")
SNOWFLAKE_SCHEMA    = os.environ.get("SNOWFLAKE_SCHEMA", "PUBLIC")
SNOWFLAKE_WAREHOUSE = os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")
SNOWFLAKE_ROLE      = os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN")

def get_private_key():
    secrets    = boto3.client("secretsmanager")
    secret     = secrets.get_secret_value(SecretId="snowflake/pos-pipeline/dev/private-key")
    key_pem    = secret["SecretString"].encode()
    private_key = load_pem_private_key(key_pem, password=None, backend=default_backend())
    return private_key

def get_snowflake_connection():
    private_key = get_private_key()
    private_key_bytes = private_key.private_bytes(
        encoding=Encoding.DER,
        format=PrivateFormat.PKCS8,
        encryption_algorithm=NoEncryption()
    )
    try:
        return snowflake.connector.connect(
            account     = SNOWFLAKE_ACCOUNT,
            user        = SNOWFLAKE_USER,
            private_key = private_key_bytes,
            database    = SNOWFLAKE_DATABASE,
            schema      = SNOWFLAKE_SCHEMA,
            warehouse   = SNOWFLAKE_WAREHOUSE,
            role        = SNOWFLAKE_ROLE
        )
    except Exception as e:
        print(json.dumps({"event": "snowflake_connection_failed", "error": str(e)}))
        raise

def fix_xlsx(body_bytes):
    input_buf  = BytesIO(body_bytes)
    output_buf = BytesIO()

    with zipfile.ZipFile(input_buf, 'r') as zin:
        names = zin.namelist()
        print(f"Files in XLSX zip: {names}")

        with zipfile.ZipFile(output_buf, 'w', zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                zout.writestr(item, zin.read(item.filename))

            if 'xl/_rels/workbook.xml.rels' not in names:
                print("Adding missing xl/_rels/workbook.xml.rels...")
                wb_xml = zin.read('xl/workbook.xml')
                tree   = ET.fromstring(wb_xml)
                sheets = [el for el in tree.iter() if el.tag.endswith('}sheet') or el.tag == 'sheet']

                rels = [
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
                    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                ]
                for i, sheet in enumerate(sheets, 1):
                    rels.append(
                        f'<Relationship Id="rId{i}" '
                        f'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
                        f'Target="worksheets/sheet{i}.xml"/>'
                    )
                rels.append('</Relationships>')
                zout.writestr('xl/_rels/workbook.xml.rels', '\n'.join(rels))

    output_buf.seek(0)
    return output_buf


def read_file(body_bytes, s3_key):
    _, ext = os.path.splitext(s3_key)
    ext    = ext.lstrip(".").lower()
    print(f"Reading file as '{ext}' (derived from S3 key: {s3_key})")
 
    if ext == "xls":
        return pd.read_excel(BytesIO(body_bytes), header=None, engine='xlrd')
 
    elif ext == "xlsx":
        try:
            return pd.read_excel(BytesIO(body_bytes), header=None, engine='openpyxl')
        except Exception as e:
            print(f"openpyxl failed: {e} — attempting relationship fix...")
            fixed = fix_xlsx(body_bytes)
            return pd.read_excel(fixed, header=None, engine='openpyxl')
 
    elif ext == "csv":
        return pd.read_csv(StringIO(body_bytes.decode("utf-8")), header=None)
 
    else:
        raise ValueError(f"Unsupported file type: '.{ext}' (key: {s3_key})")
    
def find_header_row(df_raw, max_rows=50):
    rows = []
    for idx, (i, row) in enumerate(df_raw.iterrows()):
        if idx >= max_rows:
            break
        non_null = [v for v in row.values if v is not None and not (isinstance(v, float) and pd.isna(v))]
        rows.append((idx, non_null))

    first_col_seen = {}
    data_start = None
    for i, non_null in rows:
        if not non_null:
            continue
        first_val = non_null[0]
        if first_val in first_col_seen:
            data_start = first_col_seen[first_val]
            break
        first_col_seen[first_val] = i

    header_rows = [(i, non_null) for i, non_null in rows if non_null and (data_start is None or i < data_start)]

    print(f"Found {len(header_rows)} header row(s), data starts at row {data_start}:")
    for i, non_null in header_rows:
        print(f"  Row {i}: {non_null[:6]}")
    if data_start is None:
        print(json.dumps({"event": "header_not_found", "rows_scanned": max_rows}))
        raise ValueError(f"Could not detect header row")  # ← STOP
    print(json.dumps({"event": "header_found", "header_row": int(data_start - 1)}))
    return data_start - 1


def melt_bucees(df_raw):
    df_raw.columns = [str(c).strip() for c in df_raw.columns]
    print(f"Columns after cleaning: {df_raw.columns.tolist()}")

    cols                = df_raw.columns.tolist()
    cols[0]             = 'Store'
    cols[1]             = 'Item'
    df_raw.columns      = cols

    id_vars   = ['Store', 'Item','UPC']
    week_cols = [col for col in df_raw.columns if col not in id_vars]
    print(f"Week columns ({len(week_cols)}): {week_cols[:5]}...")

    melted         = df_raw.melt(id_vars=id_vars, var_name="Week Label", value_name="Sale")
    melted.columns = [str(c).strip() for c in melted.columns]
    print(f"After melt shape: {melted.shape}")
    return melted

def string_split(df, col, delimiter='-'):
    split = df[col].astype(str).str.split(delimiter, n=1, expand=True)
    df['Store_Code'] = split[0].str.strip()
    df['Store_Name'] = split[1].str.strip()
    return df

def clean_dataframe(df_raw, store_name):
    config           = COLUMN_CONFIG[store_name]
    expected_columns = list(config.values())
    header_row       = find_header_row(df_raw)
  
    
    df         = df_raw.iloc[header_row + 1:].copy()
    df.columns = df_raw.iloc[header_row].values
    df.columns = [str(c).strip() for c in df.columns]
    df         = df.reset_index(drop=True)
    
    if store_name == "buc-ees":
        transpose_df = melt_bucees(df)
        return string_split(transpose_df,'Store')
    
    anchor_col = next((col for col in expected_columns if col in df.columns), None)
    if anchor_col:
        mask = (
            df[anchor_col].isna() |
            df[anchor_col].astype(str).str.strip().eq('') |
            df[anchor_col].astype(str).str.lower().str.contains('total|subtotal|grand', na=False)
        )
        df = df[~mask].reset_index(drop=True)
        print(f"Dropped total/empty rows using anchor: '{anchor_col}'")
    if df.empty:
        print(json.dumps({"event": "empty_after_clean", "store": store_name}))
        raise ValueError(f"DataFrame empty after cleaning for {store_name}")
    return df


def extract_columns(df, store_name):
    config     = COLUMN_CONFIG[store_name]
    rename_map = {
        cols: standard
        for standard, cols in config.items()
        if cols in df.columns
    }
    if not rename_map:
        print(json.dumps({"event": "no_columns_matched", "store": store_name,"available": df.columns.tolist()}))
        raise ValueError(f"No matching columns for {store_name}")
    print(json.dumps({"event": "columns_extracted", "store": store_name,"columns": list(rename_map.values())}))
    df_extracted = df[list(rename_map.keys())].copy()
    df_extracted.rename(columns=rename_map, inplace=True)
    return df_extracted

def get_mapping_table():
    """Read product mapping from Snowflake dim_product"""
    conn = get_snowflake_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT PROD_ID, PROD_NAME, UPC, FLAVOUR, STRENGTH
            FROM SESH_METADATA.PUBLIC.dim_product
        """)
        df = pd.DataFrame(
            cursor.fetchall(), 
            columns=[col[0] for col in cursor.description]
        )
        if df.empty:
            raise ValueError("dim_product returned 0 rows")
        print(json.dumps({"event": "mapping_table_loaded", "rows": int(len(df))}))
        return df
    except Exception as e:
        print(json.dumps({"event": "mapping_table_failed", "error": str(e)}))
        raise
    finally:
        conn.close()

def product_mapping(df, mapping_df):
    df = df.drop(columns=['PROD_ID', 'Prod_id', 'prod_id'], errors='ignore')
    df['Product UPC'] = df['Product UPC'].astype(str).str.strip()
    mapping_df['UPC'] = mapping_df['UPC'].astype(str).str.strip()

    # ── Match 1: Full UPC ────────────────────────────────────────────────────
    df_merge  = df.merge(
        mapping_df[['PROD_ID', 'UPC']],
        how='left',
        left_on='Product UPC',
        right_on='UPC'
    )
    matched   = df_merge[df_merge['PROD_ID'].notna()].copy()
    unmatched = df_merge[df_merge['PROD_ID'].isna()].copy()
    print(f"Full UPC match: {len(matched)} matched, {len(unmatched)} unmatched")

    # ── Match 2: Mapping UPC minus last char ─────────────────────────────────
    if not unmatched.empty:
        unmatched = unmatched.drop(columns=['PROD_ID', 'UPC'], errors='ignore')

        mapping_12           = mapping_df.copy()
        mapping_12['UPC_12'] = mapping_12['UPC'].astype(str).str[:-1].str[-12:]
        mapping_12           = mapping_12.drop_duplicates(subset=['UPC_12'])

        df_fallback = unmatched.merge(
            mapping_12[['PROD_ID', 'UPC_12']],
            how='left',
            left_on='Product UPC',
            right_on='UPC_12'
        )
        df_fallback.drop(columns=['UPC_12'], inplace=True)

        matched_12   = df_fallback[df_fallback['PROD_ID'].notna()].copy()
        unmatched_12 = df_fallback[df_fallback['PROD_ID'].isna()].copy()
        print(f"Mapping -1 char match: {len(matched_12)} matched, {len(unmatched_12)} unmatched")

        # ── Match 3: Last 12 digits of mapping UPC ───────────────────────────
        if not unmatched_12.empty:
            unmatched_12 = unmatched_12.drop(columns=['PROD_ID', 'UPC'], errors='ignore')

            mapping_last12            = mapping_df.copy()
            mapping_last12['UPC_L12'] = mapping_last12['UPC'].astype(str).str[-12:]
            mapping_last12            = mapping_last12.drop_duplicates(subset=['UPC_L12'])

            df_fallback2 = unmatched_12.merge(
                mapping_last12[['PROD_ID', 'UPC_L12']],
                how='left',
                left_on='Product UPC',
                right_on='UPC_L12'
            )
            df_fallback2.drop(columns=['UPC_L12'], inplace=True)

            matched_last12   = df_fallback2[df_fallback2['PROD_ID'].notna()].copy()
            unmatched_last12 = df_fallback2[df_fallback2['PROD_ID'].isna()].copy()
            print(f"Last 12-digit mapping match: {len(matched_last12)} matched, {len(unmatched_last12)} unmatched")

            # ── Match 4: Remove last digit from mapping UPC only ─────────────
            if not unmatched_last12.empty:
                unmatched_last12 = unmatched_last12.drop(columns=['PROD_ID', 'UPC'], errors='ignore')

                mapping_rm1            = mapping_df.copy()
                mapping_rm1['UPC_RM1'] = mapping_rm1['UPC'].astype(str).str[:-1]
                mapping_rm1            = mapping_rm1.drop_duplicates(subset=['UPC_RM1'])

                # Convert input UPC to int before joining
                unmatched_last12['UPC_INT'] = unmatched_last12['Product UPC'].apply(
                    lambda x: str(int(float(x))) if pd.notna(x) and str(x).replace('.','').isdigit() else str(x)
                )

                df_fallback3 = unmatched_last12.merge(
                    mapping_rm1[['PROD_ID', 'UPC_RM1']],
                    how='left',
                    left_on='UPC_INT',
                    right_on='UPC_RM1'
                )
                df_fallback3.drop(columns=['UPC_RM1', 'UPC_INT'], inplace=True)

                matched_rm1   = df_fallback3[df_fallback3['PROD_ID'].notna()].copy()
                unmatched_rm1 = df_fallback3[df_fallback3['PROD_ID'].isna()].copy()
                print(f"Mapping -1 digit match: {len(matched_rm1)} matched, {len(unmatched_rm1)} unmatched")

                # ── Match 5: Full UPC after converting to int ─────────────────
                if not unmatched_rm1.empty:
                    unmatched_rm1 = unmatched_rm1.drop(columns=['PROD_ID', 'UPC'], errors='ignore')

                    # Convert both to int string before joining
                    unmatched_rm1['UPC_INT'] = unmatched_rm1['Product UPC'].apply(
                        lambda x: str(int(float(x))) if pd.notna(x) and str(x).replace('.','').isdigit() else str(x)
                    )
                    mapping_int           = mapping_df.copy()
                    mapping_int['UPC_INT'] = mapping_int['UPC'].apply(
                        lambda x: str(int(float(x))) if pd.notna(x) and str(x).replace('.','').isdigit() else str(x)
                    )
                    mapping_int = mapping_int.drop_duplicates(subset=['UPC_INT'])

                    df_fallback4 = unmatched_rm1.merge(
                        mapping_int[['PROD_ID', 'UPC_INT']],
                        how='left',
                        left_on='UPC_INT',
                        right_on='UPC_INT'
                    )
                    df_fallback4.drop(columns=['UPC_INT'], inplace=True)

                    matched_int   = df_fallback4[df_fallback4['PROD_ID'].notna()].copy()
                    unmatched_int = df_fallback4[df_fallback4['PROD_ID'].isna()].copy()
                    print(f"Full UPC int match: {len(matched_int)} matched, {len(unmatched_int)} unmatched")

                    df_merge = pd.concat([matched, matched_12, matched_last12, matched_rm1, matched_int, unmatched_int], ignore_index=True)
                else:
                    df_merge = pd.concat([matched, matched_12, matched_last12, matched_rm1, unmatched_rm1], ignore_index=True)
            else:
                df_merge = pd.concat([matched, matched_12, matched_last12, unmatched_last12], ignore_index=True)
    else:
        df_merge = matched.copy()
    unmatched     = df_merge['PROD_ID'].eq(0).sum()
    unmatched_upcs = df_merge[df_merge['PROD_ID'].eq(0)]['Product UPC'].tolist()
    print(json.dumps({
        "event"    : "product_mapping_complete",
        "total"    : int(len(df_merge)),
        "matched"  : int(len(df_merge) - unmatched),
        "unmatched": int(unmatched)
    }))
    if unmatched > 0:
        print(json.dumps({"event": "product_mapping_failed",
                          "unmatched_upcs": unmatched_upcs}))
        raise ValueError(f"Product mapping failed for {unmatched} UPCs")
    # Rename Product UPC for consistency
    df_merge['Product_UPC'] = df_merge['Product UPC']
    df_merge.drop(columns=['Product UPC', 'UPC'], inplace=True, errors='ignore')

    # Clean PROD_ID
    df_merge['PROD_ID'] = pd.to_numeric(df_merge['PROD_ID'], errors='coerce').fillna(0).astype(int)

    return df_merge

def handle_missing(df,missing):
    for col, values in missing.items():

        if col == "EQ Units":
            divisor = float(values[0])
            df["Sales"]    = pd.to_numeric(df["Sales"], errors='coerce')
            df["EQ_Units"] = (df["Sales"] / divisor).round().astype(int)

        elif col == "Store":
            df["Store"] = values[0]
    # elif missing_col == "Sales":
    #     df["Sales"] = (df["EQ Units"] * divisor).round(2)
    #     print(f"[{store_name}] 'Sales' derived from EQ Units * {divisor}")

    return df

def normalize_week_ending(df):
    def nearest_saturday(date):
        day = date.dayofweek

        days_to_prev_sat = day - 5 if day >= 5 else day + 2
        days_to_next_sat = (5 - day) % 7

        prev_sat = date - pd.Timedelta(days=days_to_prev_sat)
        next_sat = date + pd.Timedelta(days=days_to_next_sat)

        if (date - prev_sat) <= (next_sat - date):
            return prev_sat
        return next_sat
    
    def parse_date(val):
        val         = str(val).strip()
        # date_format = os.environ.get('DATE_FORMAT')
        if len(val) == 6 and val.isdigit():
            return pd.to_datetime(val + '1', format='%Y%W%w')

        return pd.to_datetime(val)
    if not pd.api.types.is_datetime64_any_dtype(df['Trans_date']):
        try:
            df['Trans_date'] = df['Trans_date'].apply(parse_date)
        except Exception as e:
            print(json.dumps({"event": "date_parse_failed", "error": str(e)}))
            raise  

    max_date    = df['Trans_date'].max()
    week_ending = nearest_saturday(max_date).normalize()
    df['Week_Ending'] = week_ending
    print(json.dumps({"event": "week_ending_normalized","week_ending": str(df['Week_Ending'].iloc[0])}))
    return df

def clean_postal_code(df):
    if 'Postal_Code' not in df.columns:
        return df
    
    def normalize_zip(val):
        if pd.isna(val) or str(val).strip() == '':
            return None
        
        val = str(val).strip()
        
        digits_only = ''.join(filter(str.isdigit, val))
        
        if len(digits_only) >= 9:
            # ZIP+4 format (123456789) → take first 5
            return digits_only[:5]
        elif len(digits_only) == 5:
            # Already 5 digits
            return digits_only
        else:
            return digits_only[:5]
    
    df['Postal_Code'] = df['Postal_Code'].apply(normalize_zip)
    return df

def get_known_locations():
    """Load all location data from Snowflake dim_location joined with dim tables"""
    conn = get_snowflake_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                dl.loc_id,
                dl.loc_name,
                dl.store_code::STRING  as store_code,
                dl.address,
                dc.city_name           as city,
                ds.state_name          as state,
                dco.county_name        as county,
                dc.postal_code
            FROM SESH_METADATA.PUBLIC.dim_location dl
            LEFT JOIN SESH_METADATA.PUBLIC.dim_city    dc  ON dl.city_id   = dc.city_id
            LEFT JOIN SESH_METADATA.PUBLIC.dim_state   ds  ON dl.state_id  = ds.state_id
            LEFT JOIN SESH_METADATA.PUBLIC.dim_county  dco ON dl.county_id = dco.county_id
        """)
        df = pd.DataFrame(
            cursor.fetchall(),
            columns=[col[0] for col in cursor.description]
        )
        if df.empty:
            raise ValueError("dim_location returned 0 rows")  # ← STOP
        print(json.dumps({"event": "known_locations_loaded", "rows": len(df)}))
        return df
    except Exception as e:
        print(json.dumps({"event": "known_locations_failed", "error": str(e)}))
        raise
    finally:
        conn.close()


def check_new_stores(df, store_name, s3_client):
    """Dynamically check new stores based on whatever columns the input file has"""
    print(json.dumps({"event": "check_new_stores_called", "notify_email": NOTIFY_EMAIL, "store": store_name}))
    NOTIFY_EMAIL = os.environ.get("NOTIFY_EMAIL")

    # ── Load known locations from Snowflake ──────────────────────────────────
    try:
        known_df = get_known_locations()
    except Exception as e:
        print(f"Could not load known locations: {e}")
        return set()

    # ── Define column mapping between input file and Snowflake ───────────────
    col_mapping = {
        'Store_Code' : 'store_code',
        'Store_Name' : 'loc_name',
        'Address'    : 'address',
        'City'       : 'city',
        'State'      : 'state',
        'County'     : 'county',
        'Postal_Code': 'postal_code',
    }

    # ── Find which columns exist in both input file and known locations ───────
    matched_cols = {
        input_col: sf_col
        for input_col, sf_col in col_mapping.items()
        if input_col in df.columns and sf_col in known_df.columns
    }

    if not matched_cols:
        print(f"No matching location columns found for {store_name} — skipping check")
        return set()

    print(f"Checking new stores using columns: {list(matched_cols.keys())}")

    # ── Build composite key from available columns ───────────────────────────
    def make_key(row, cols):
        return "|".join(
            str(row[c]).strip().upper() if pd.notna(row[c]) else ""
            for c in cols
        )

    input_cols  = list(matched_cols.keys())
    sf_cols     = list(matched_cols.values())

    input_keys  = set(df.apply(lambda row: make_key(row, input_cols), axis=1))
    known_keys  = set(known_df.apply(lambda row: make_key(row, sf_cols), axis=1))

    new_stores  = input_keys - known_keys
    # Remove empty keys
    new_stores  = {k for k in new_stores if k.replace('|', '').strip()}

    print(f"Input: {len(input_keys)}, Known: {len(known_keys)}, New: {len(new_stores)}")

    if new_stores:
        print(json.dumps({"event": "new_stores_detected", "store": store_name,"new_stores": list(new_stores), "count": len(new_stores)}))

        if NOTIFY_EMAIL:
            try:
                ses_client.send_email(
                    Source      = NOTIFY_EMAIL,
                    Destination = {"ToAddresses": [NOTIFY_EMAIL]},
                    Message     = {
                        "Subject": {
                            "Data": f"⚠️ New Stores Detected — {store_name}"
                        },
                        "Body": {
                            "Text": {
                                "Data": f"New stores detected in {store_name} file.\n\n"
                                        f"Matched on columns: {', '.join(input_cols)}\n\n"
                                        f"New store keys:\n" +
                                        "\n".join(sorted(new_stores)) +
                                        f"\n\nTotal: {len(new_stores)}\n\n"
                                        f"Transformation stopped. Please add to dim_location."
                            }
                        }
                    }
                )
                print(f"Notification sent to {NOTIFY_EMAIL}")
            except Exception as e:
                print(f"Failed to send email: {e}")
        raise ValueError(f"New stores detected: {new_stores}") 
    return new_stores

def process_attachment(s3_client, body_bytes, store_name, file_name, timestamp, output_bucket):
    try:
        vendor_config = VENDOR_CONFIG.get(store_name, {})
        mapping_bucket = get_mapping_table()

        if not COLUMN_CONFIG or store_name not in COLUMN_CONFIG:
            print(f"No COLUMN_CONFIG entry for store '{store_name}' — skipping transform.")
            return None

        df_raw = read_file(body_bytes, file_name)
        print(f"Raw DataFrame shape: {df_raw.shape}")

        df = clean_dataframe(df_raw, store_name)
        print(f"Cleaned DataFrame shape: {df.shape}, columns: {list(df.columns)}")

        df_extracted = extract_columns(df, store_name)
        if df_extracted is None:
            print(f"No matching columns found for store '{store_name}' in '{file_name}'")
            return None
        print(f"Extracted shape: {df_extracted.shape}")

        new_stores = check_new_stores(df_extracted, store_name, s3_client)
        if new_stores:
            print(f"New stores detected — stopping transformation: {new_stores}")
            return None  # ← stop here

        df_extracted = product_mapping(df_extracted, mapping_bucket)
        df_extracted = normalize_week_ending(df_extracted)

        missing = vendor_config.get("missing", [])
        if missing:
            df_extracted = handle_missing(df_extracted, missing)

        # ← Add this block to clean numeric columns
        numeric_cols = ["EQ_Units", "Sales", "EQ Units"]
        for col in numeric_cols:
            if col in df_extracted.columns:
                df_extracted[col] = pd.to_numeric(df_extracted[col], errors='coerce').fillna(0)

        df_extracted = clean_postal_code(df_extracted)
        base_name  = file_name.rsplit('.', 1)[0]
        output_key = f"pos_transformed/{store_name}/{timestamp}/{base_name}.csv"

        csv_buffer = StringIO()
        df_extracted.to_csv(csv_buffer, index=False)
        s3_client.put_object(Bucket=output_bucket, Key=output_key, Body=csv_buffer.getvalue())
        print(json.dumps({"event": "transform_complete", "store": store_name,
                          "file": file_name, "output_key": output_key,
                          "rows": len(df_extracted)}))
        return output_key
    except ValueError as e:
        print(json.dumps({"event": "transform_stopped", "store": store_name,"file": file_name, "reason": str(e)}))
        raise  # ← STOP, bubble up to index.py handler
    except Exception as e:
        print(json.dumps({"event": "transform_unexpected_error", "store": store_name,"file": file_name, "error": str(e)}))
        raise