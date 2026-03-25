import sys
import os
from supabase import create_client, Client

# Add the current directory to sys.path to find intelligence_service
sys.path.append(os.getcwd())
from intelligence_service import IntelligenceService

# Hardcoded credentials from main.py
SUPABASE_URL = "https://xowqknkxnbalzgapohoo.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhvd3Frbmt4bmJhbHpnYXBvaG9vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5Njc2OTEsImV4cCI6MjA4OTU0MzY5MX0.dPUU8ffHfJRD-aiAvj9kkNqH5TSi88dpGOkBSPidGZQ"

def debug_scraper():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    service = IntelligenceService(supabase)
    
    print("--- Starting Manual Scraper Debug ---")
    try:
        print("Fetching and processing data from WHO/CDC...")
        entries = service.fetch_latest_intelligence()
        print(f"SUCCESS: Processed {len(entries)} entries.")
        if len(entries) > 0:
            print(f"Sample Entry: {entries[0]['title']}")
        print("--- Scraper Execution Finished ---")
    except Exception as e:
        print(f"--- ERROR: {e} ---")

if __name__ == "__main__":
    debug_scraper()
