import asyncio
import os
import logging
import zipfile
from datetime import datetime
from pathlib import Path
from playwright.async_api import async_playwright
import boto3

# ── Config ────────────────────────────────────────────────────────────────────
BYZZER_URL   = "https://www.byzzer.ai/#/auth/sign_in"
EMAIL        = os.environ["BYZZER_EMAIL"]
PASSWORD     = os.environ["BYZZER_PASSWORD"]
REPORT_NAME  = os.environ.get("BYZZER_REPORT", "My Report")
DOWNLOAD_DIR = Path("/tmp/byzzer") / datetime.today().strftime("%Y-%m-%d")
HEADLESS     = os.environ.get("HEADLESS", "true").lower() == "true"
RAW_BUCKET   = os.environ["RAW_BUCKET_EMAIL"]
S3_PREFIX    = "pos-files"
S3_DEBUG     = "ec2-scripts/debug"

s3 = boto3.client("s3")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/tmp/byzzer.log"),
    ]
)
log = logging.getLogger(__name__)

# ── Helper ────────────────────────────────────────────────────────────────────

def upload_screenshot(local_path: str, s3_key: str):
    try:
        with open(local_path, "rb") as f:
            s3.put_object(Bucket=RAW_BUCKET, Key=s3_key, Body=f.read(), ContentType="image/png")
        log.info(f"Screenshot uploaded to s3://{RAW_BUCKET}/{s3_key}")
    except Exception as e:
        log.warning(f"Failed to upload screenshot {local_path}: {e}")


def extract_and_upload_zip(zip_path: Path) -> list[str]:
    uploaded_keys = []
    extract_dir   = zip_path.parent / zip_path.stem

    log.info(f"Extracting zip: {zip_path}")
    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(extract_dir)
        extracted_files = list(extract_dir.rglob('*'))
        log.info(f"Extracted {len(extracted_files)} file(s): {[f.name for f in extracted_files]}")

    for file_path in extracted_files:
        if not file_path.is_file():
            continue

        s3_key = f"{S3_PREFIX}/nielsen/{file_path.name}"
        with open(file_path, "rb") as f:
            s3.put_object(Bucket=RAW_BUCKET, Key=s3_key, Body=f.read())
        log.info(f"Uploaded extracted file to s3://{RAW_BUCKET}/{s3_key}")
        uploaded_keys.append(s3_key)

    return uploaded_keys


def upload_file(file_path: Path) -> str:
    s3_key = f"{S3_PREFIX}/nielsen/{file_path.name}"
    with open(file_path, "rb") as f:
        s3.put_object(Bucket=RAW_BUCKET, Key=s3_key, Body=f.read())
    log.info(f"Uploaded to s3://{RAW_BUCKET}/{s3_key}")
    return s3_key

# ── Steps ─────────────────────────────────────────────────────────────────────

async def login(page):
    log.info("Navigating to login page...")
    await page.goto(BYZZER_URL)
    await page.wait_for_load_state("domcontentloaded")

    email_selector = 'input[type="email"], input[name="email"], input[placeholder*="email" i]'
    await page.wait_for_selector(email_selector, timeout=30_000)
    log.info("Login form loaded.")

    await page.screenshot(path="/tmp/debug_login_page.png")
    upload_screenshot("/tmp/debug_login_page.png", f"{S3_DEBUG}/debug_login_page.png")

    await page.fill(email_selector, EMAIL)

    password_selector = 'input[type="password"]'
    await page.fill(password_selector, PASSWORD)

    await page.screenshot(path="/tmp/debug_before_signin.png", full_page=True)
    upload_screenshot("/tmp/debug_before_signin.png", f"{S3_DEBUG}/debug_before_signin.png")

    buttons = await page.locator("button").all()
    for btn in buttons:
        log.info(f"Button found: {repr(await btn.inner_text())} type={await btn.get_attribute('type')}")

    sign_in_btn = page.locator('[data-test="sign-in_sing_in"]')
    await sign_in_btn.wait_for(state="visible", timeout=15_000)
    await page.wait_for_function(
        "!document.querySelector('.byzzer-button--disabled [data-test=\"sign-in_sing_in\"]')"
    )
    await sign_in_btn.click()

    await page.screenshot(path="/tmp/debug_after_signin.png", full_page=True)
    upload_screenshot("/tmp/debug_after_signin.png", f"{S3_DEBUG}/debug_after_signin.png")

    await page.wait_for_url(lambda url: "/auth/" not in url and "sign_in" not in url, timeout=60_000)
    log.info("Login successful.")


async def find_and_download_report(page):
    log.info("Navigating to Data On Demand...")
    await page.locator('.dashboard-nav-item__text:has-text("Data On Demand")').click()
    await page.wait_for_load_state("domcontentloaded")

    await page.wait_for_selector('.ag-root', timeout=30_000)
    await page.wait_for_timeout(1000)

    name_filter = page.locator('input[aria-label="Run Name Filter Input"]')
    await name_filter.wait_for(state="visible", timeout=10_000)
    await name_filter.fill(REPORT_NAME)
    await page.wait_for_timeout(1500)
    log.info(f"Filtered by Run Name: {REPORT_NAME}")

    status_filter = page.locator('input[aria-label="Status Filter Input"]')
    await status_filter.wait_for(state="visible", timeout=10_000)
    await status_filter.fill("run complete")
    await page.wait_for_timeout(1500)
    log.info("Filtered by Status: run complete")

    run_date_header = page.locator('.ag-header-cell[col-id="endDtm"]')
    await run_date_header.click()
    await page.wait_for_timeout(500)
    await run_date_header.click()
    await page.wait_for_timeout(1000)
    log.info("Sorted by Run Date descending.")

    await page.screenshot(path="/tmp/debug_grid_filtered.png", full_page=True)
    upload_screenshot("/tmp/debug_grid_filtered.png", f"{S3_DEBUG}/debug_grid_filtered.png")

    download_trigger = page.locator('div.dod-history__download-menu-trigger').first
    await download_trigger.wait_for(state="visible", timeout=15_000)
    await download_trigger.click()
    log.info("Download menu opened.")

    await page.screenshot(path="/tmp/debug_download_menu.png")
    upload_screenshot("/tmp/debug_download_menu.png", f"{S3_DEBUG}/debug_download_menu.png")

    download_option = (
        page.locator('[class*="download-menu"] [class*="item"]').first.or_(
        page.locator('li:has-text("Download")').first).or_(
        page.locator('button:has-text("Download")').first)
    )
    await download_option.wait_for(state="visible", timeout=10_000)

    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    async with page.expect_download(timeout=60_000) as dl_info:
        await download_option.click()

    download = await dl_info.value
    failure  = await download.failure()
    if failure:
        raise RuntimeError(f"Download failed: {failure}")

    dest = DOWNLOAD_DIR / download.suggested_filename
    await download.save_as(dest)
    log.info(f"Downloaded: {dest.name} ({dest.stat().st_size} bytes)")

    # ── Handle zip vs regular file ────────────────────────────────────────────
    if dest.suffix.lower() == '.zip':
        log.info("Downloaded file is a ZIP — extracting...")
        uploaded_keys = extract_and_upload_zip(dest)
        if not uploaded_keys:
            raise RuntimeError("ZIP was empty or contained no uploadable files")
        log.info(f"Uploaded {len(uploaded_keys)} file(s) from ZIP")
        return uploaded_keys
    else:
        s3_key = upload_file(dest)
        return [s3_key]


# ── Main ──────────────────────────────────────────────────────────────────────

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=HEADLESS,
            args=["--no-sandbox", "--disable-dev-shm-usage"],
            downloads_path=str(DOWNLOAD_DIR),
        )
        context = await browser.new_context(
            accept_downloads=True,
            viewport={"width": 1280, "height": 900},
        )
        page = await context.new_page()

        page.on(
            "console",
            lambda msg: log.debug(f"[browser] {msg.text}") if msg.type == "error" else None
        )

        try:
            await login(page)
            s3_keys = await find_and_download_report(page)
            log.info(f"Done. Report(s) uploaded to S3: {s3_keys}")

        except Exception as e:
            await page.screenshot(path="/tmp/debug_error.png", full_page=True)
            upload_screenshot("/tmp/debug_error.png", f"{S3_DEBUG}/debug_error.png")
            log.error(f"Script failed: {e}")
            raise

        finally:
            await context.close()
            await browser.close()


if __name__ == "__main__":
    asyncio.run(main())