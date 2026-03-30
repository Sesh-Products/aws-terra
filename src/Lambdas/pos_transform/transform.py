
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
product_map_bucket = "product-upc-mapping"
product_map_bucket_key    = "product-sku.csv"

VENDOR_CONFIG = json.loads(os.environ.get("VENDOR_CONFIG", "{}"))
COLUMN_CONFIG = json.loads(os.environ.get("COLUMN_CONFIG", "{}"))
response = s3.get_object(Bucket=product_map_bucket, Key=product_map_bucket_key)
mapping_bucket = get_mapping_table()

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
    return snowflake.connector.connect(
        account     = SNOWFLAKE_ACCOUNT,
        user        = SNOWFLAKE_USER,
        private_key = private_key_bytes,
        database    = SNOWFLAKE_DATABASE,
        schema      = SNOWFLAKE_SCHEMA,
        warehouse   = SNOWFLAKE_WAREHOUSE,
        role        = SNOWFLAKE_ROLE
    )

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

    return df


def extract_columns(df, store_name):
    config     = COLUMN_CONFIG[store_name]
    rename_map = {
        cols: standard
        for standard, cols in config.items()
        if cols in df.columns
    }
    if not rename_map:
        return None
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
        return df
    finally:
        conn.close()

def product_mapping(df, mapping_df):
    """Match Product UPC to dim_product and return PROD_ID"""
    
    # Normalize UPC columns
    df['Product UPC'] = df['Product UPC'].astype(str).str.strip()
    mapping_df['UPC'] = mapping_df['UPC'].astype(str).str.strip()

    # Direct match on full UPC
    df_merge = df.merge(
        mapping_df[['PROD_ID', 'UPC']],
        how='left',
        left_on='Product UPC',
        right_on='UPC'
    )

    matched   = df_merge[df_merge['PROD_ID'].notna()].copy()
    unmatched = df_merge[df_merge['PROD_ID'].isna()].copy()

    print(f"Direct match: {len(matched)} matched, {len(unmatched)} unmatched")

    # Fallback — match on first 11 digits
    if not unmatched.empty:
        unmatched = unmatched.drop(columns=['PROD_ID', 'UPC'], errors='ignore')
        unmatched['product_11'] = unmatched['Product UPC'].astype(str).str[:11]
        mapping_df['UPC_11'] = mapping_df['UPC'].astype(str).str[:11]

        df_fallback = unmatched.merge(
            mapping_df[['PROD_ID', 'UPC_11']],
            how='left',
            left_on='product_11',
            right_on='UPC_11'
        )
        df_fallback.drop(columns=['product_11', 'UPC_11'], inplace=True)

        matched_11   = df_fallback[df_fallback['PROD_ID'].notna()].copy()
        unmatched_11 = df_fallback[df_fallback['PROD_ID'].isna()].copy()

        print(f"11-digit fallback: {len(matched_11)} matched, {len(unmatched_11)} unmatched")

        df_merge = pd.concat([matched, matched_11, unmatched_11], ignore_index=True)
    
    # Rename Product UPC to Product_UPC for consistency
    df_merge['Product_UPC'] = df_merge['Product UPC']
    df_merge.drop(columns=['Product UPC', 'UPC'], inplace=True, errors='ignore')

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
        df['Trans_date'] = df['Trans_date'].apply(parse_date)

    max_date    = df['Trans_date'].max()
    week_ending = nearest_saturday(max_date).normalize()

    df['Week_Ending'] = week_ending
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


def process_attachment(s3_client, body_bytes, store_name, file_name, timestamp, output_bucket):
    vendor_config = VENDOR_CONFIG.get(store_name, {})

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

    print(f"Saved transformed CSV to: s3://{output_bucket}/{output_key}")
    return output_key