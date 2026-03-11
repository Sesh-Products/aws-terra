
import os
import json
import pandas as pd
import zipfile
import xml.etree.ElementTree as ET
from io import StringIO, BytesIO

COLUMN_CONFIG = json.loads(os.environ.get("COLUMN_CONFIG", "{}"))


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

    first_col = df_raw.columns[0]
    df_raw.rename(columns={first_col: 'Store'}, inplace=True)

    id_vars   = ['Store', 'Item']
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
    expected_columns = [cols[0] for cols in config.values()]
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
        cols[0]: standard
        for standard, cols in config.items()
        if cols[0] in df.columns
    }
    if not rename_map:
        return None
    df_extracted = df[list(rename_map.keys())].copy()
    df_extracted.rename(columns=rename_map, inplace=True)
    return df_extracted

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

    base_name  = file_name.rsplit('.', 1)[0]
    output_key = f"pos_transformed/{store_name}/{timestamp}/{base_name}.csv"

    csv_buffer = StringIO()
    df_extracted.to_csv(csv_buffer, index=False)
    s3_client.put_object(Bucket=output_bucket, Key=output_key, Body=csv_buffer.getvalue())

    print(f"Saved transformed CSV to: s3://{output_bucket}/{output_key}")
    return output_key