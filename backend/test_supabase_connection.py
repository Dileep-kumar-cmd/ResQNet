"""
Script to test and initialize the Supabase PostgreSQL connection for ResQNet.
Run: python test_supabase_connection.py
"""
import asyncio
import sys
from sqlalchemy import text
from app.core.config import settings
from app.db.database import engine, Base
from app.db.models import User, Shelter, SOSLog

async def test_supabase():
    print("=" * 60)
    print("ResQNet Supabase Database Initializer & Health Check")
    print("=" * 60)
    print(f"Configured DATABASE_URL: {settings.DATABASE_URL[:25]}... (hidden credentials)")
    print(f"Resolved Engine URL:     {settings.SQLALCHEMY_DATABASE_URL[:35]}...")
    print("-" * 60)

    try:
        # Step 1: Connect and test query
        print("[1/3] Testing network connection to PostgreSQL / Supabase...")
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT version();"))
            version_str = str(result.scalar() or "Unknown")
            print(f"       Connected successfully!")
            print(f"       Postgres version: {version_str[:50]}...")

        # Step 2: Create tables if not exist
        print("[2/3] Verifying and applying ResQNet tables (Base.metadata.create_all)...")
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        print("       All tables verified (users, shelters, medical_infra, emergency_contacts, sos_logs, sync_conflicts_audit)!")

        # Step 3: Check counts
        print("[3/3] Checking table record counts...")
        async with engine.connect() as conn:
            res_users = await conn.execute(text("SELECT count(*) FROM users;"))
            res_shelters = await conn.execute(text("SELECT count(*) FROM shelters;"))
            res_sos = await conn.execute(text("SELECT count(*) FROM sos_logs;"))
            print(f"       Users:    {res_users.scalar()}")
            print(f"       Shelters: {res_shelters.scalar()}")
            print(f"       SOS Logs: {res_sos.scalar()}")

        print("-" * 60)
        print(" SUCCESS: ResQNet database is fully deployed and operational!")
        print("=" * 60)

    except Exception as e:
        print(f"\n Connection Error: {e}", file=sys.stderr)
        print("\nTroubleshooting tips:")
        print("1. Ensure you provided the correct Supabase database password.")
        print("2. Check if your DATABASE_URL in backend/.env is formatted as:")
        print("   postgresql://postgres:[YOUR-PASSWORD]@db.iljgykyxlnkdvdjgxfyx.supabase.co:5432/postgres")
        print("3. Or copy-paste 'backend/supabase_schema.sql' directly into the Supabase SQL Editor.")

if __name__ == "__main__":
    asyncio.run(test_supabase())
