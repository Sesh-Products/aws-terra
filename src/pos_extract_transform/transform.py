
import os
import json
import pandas as pd
import zipfile
import xml.etree.ElementTree as ET
from io import StringIO, BytesIO
import boto3

s3 = boto3.client("s3")
product_map_bucket = "product-upc-mapping"
product_map_bucket_key    = "product-sku.csv"

COLUMN_CONFIG = json.loads(os.environ.get("COLUMN_CONFIG", "{}"))
response = s3.get_object(Bucket=product_map_bucket, Key=product_map_bucket_key)
mapping_bucket = df = pd.read_csv(BytesIO(response["Body"].read()))

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


def read_file(body_bytes, file_name):
    if body_bytes[:4] == b'\xD0\xCF\x11\xE0':
        print("Detected format: XLS (binary)")
        return pd.read_excel(BytesIO(body_bytes), header=None, engine='xlrd')

    elif body_bytes[:2] == b'PK':
        print("Detected format: XLSX (zip)")
        try:
            return pd.read_excel(BytesIO(body_bytes), header=None, engine='openpyxl')
        except Exception as e:
            print(f"openpyxl failed: {e} — attempting relationship fix...")
            fixed = fix_xlsx(body_bytes)
            return pd.read_excel(fixed, header=None, engine='openpyxl')

    else:
        print("Detected format: CSV")
        return pd.read_csv(StringIO(body_bytes.decode('utf-8')), header=None)



def find_header_row(df_raw, expected_columns):
    expected_lower = [col.lower() for col in expected_columns]
    best_row, best_score = 0, 0

    for i, row in df_raw.iterrows():
        row_values = [str(v).strip().lower() for v in row.values]
        score = sum(1 for col in expected_lower if col in row_values)
        if score > best_score:
            best_score = score
            best_row   = i

    print(f"Header detected at row {best_row} with {best_score} matching columns")
    return best_row


def melt_bucees(df_raw):
    df_raw         = df_raw.iloc[3:].reset_index(drop=True)
    df_raw.columns = df_raw.iloc[0].values
    df_raw         = df_raw.iloc[1:].reset_index(drop=True)
    df_raw.columns = [str(c).strip() for c in df_raw.columns]

    
    cols                = df_raw.columns.tolist()
    cols[0]             = 'Store'
    cols[1]             = 'Item'
    df_raw.columns      = cols
    print(f"Columns after cleaning: {df_raw.columns.tolist()}")

    id_vars   = ['Store', 'Item','UPC']
    week_cols = [col for col in df_raw.columns if col not in id_vars]
    print(f"Week columns ({len(week_cols)}): {week_cols[:5]}...")

    melted         = df_raw.melt(id_vars=id_vars, var_name="Week Label", value_name="Sale")
    melted.columns = [str(c).strip() for c in melted.columns]
    print(f"After melt shape: {melted.shape}")
    return melted


def clean_dataframe(df_raw, store_name):
    if store_name == "buc-ees":
        return melt_bucees(df_raw)

    config           = COLUMN_CONFIG[store_name]
    expected_columns = list(config.values())
    header_row       = find_header_row(df_raw, expected_columns)

    df         = df_raw.iloc[header_row + 1:].copy()
    df.columns = df_raw.iloc[header_row].values
    df.columns = [str(c).strip() for c in df.columns]
    df         = df.reset_index(drop=True)

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

def product_mapping(df, mapping_bucket):
    original_cols = df.columns.tolist()

    df['Product UPC']                         = df['Product UPC'].astype(int).astype(str)
    mapping_bucket['Unit (Can Eaches)']       = mapping_bucket['Unit (Can Eaches)'].astype(str)
    mapping_bucket['Master Case (11 Digits)'] = mapping_bucket['Master Case (11 Digits)'].astype(str)
    mapping_bucket['Carton (Roll 5 pack)']    = mapping_bucket['Carton (Roll 5 pack)'].astype(str)

    df_merge = df.merge(
        mapping_bucket,
        how='left',
        left_on='Product UPC',
        right_on='Unit (Can Eaches)'
    )

    matched   = df_merge[df_merge['Unit (Can Eaches)'].notna()].copy()
    unmatched = df_merge[df_merge['Unit (Can Eaches)'].isna()].copy()

    matched['Product_UPC'] = matched['Unit (Can Eaches)']

    if not unmatched.empty:
        unmatched = unmatched.drop(columns=mapping_bucket.columns.tolist(), errors='ignore')

        unmatched['product_11'] = unmatched['Product UPC'].astype(str).str[:11]

        df_fallback_merge = unmatched.merge(
            mapping_bucket,
            how='left',
            left_on='product_11',
            right_on='Master Case (11 Digits)'
        )
        df_fallback_merge.drop(columns=['product_11'], inplace=True)

        matched_11   = df_fallback_merge[df_fallback_merge['Master Case (11 Digits)'].notna()].copy()
        unmatched_11 = df_fallback_merge[df_fallback_merge['Master Case (11 Digits)'].isna()].copy()

        matched_11['Product_UPC'] = matched_11['Master Case (11 Digits)']

        if not unmatched_11.empty:
            unmatched_11 = unmatched_11.drop(columns=mapping_bucket.columns.tolist(), errors='ignore')

            df_carton_merge = unmatched_11.merge(
                mapping_bucket,
                how='left',
                left_on='Product UPC',
                right_on='Carton (Roll 5 pack)'
            )

            df_carton_merge['Product_UPC'] = df_carton_merge['Carton (Roll 5 pack)']

            df_merge = pd.concat([matched, matched_11, df_carton_merge], ignore_index=True)
        else:
            df_merge = pd.concat([matched, matched_11], ignore_index=True)
    else:
        print("Mergeing Failed")

    df_merge = df_merge[original_cols + ['Product_UPC']]
    df_merge.drop(columns=['Product UPC'], inplace=True)
    return df_merge

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

def process_attachment(s3_client, body_bytes, store_name, file_name, timestamp, output_bucket):

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

    df_extracted = product_mapping(df_extracted,mapping_bucket)

    df_extracted = normalize_week_ending(df_extracted)

    base_name  = file_name.rsplit('.', 1)[0]
    output_key = f"pos_transformed/{store_name}/{timestamp}/{base_name}.csv"

    csv_buffer = StringIO()
    df_extracted.to_csv(csv_buffer, index=False)
    s3_client.put_object(Bucket=output_bucket, Key=output_key, Body=csv_buffer.getvalue())

    print(f"Saved transformed CSV to: s3://{output_bucket}/{output_key}")
    return output_key