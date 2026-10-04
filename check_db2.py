import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text

DATABASE_URL = "postgresql://postgres.konpxcjidkvmifwmuwqn:Dilpeshmehta1980param2012@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def main():
    db = SessionLocal()
    
    try:
        # Check stocks
        query = text("""
            SELECT id, stock_tag, stock_category, stock_type, product_tag, is_latest, status, karat, cent, display_order, created_at 
            FROM stocks 
            ORDER BY created_at DESC 
            LIMIT 10
        """)
        
        result = db.execute(query).fetchall()
        print("--- TOP 10 RECENT STOCKS ---")
        for row in result:
            print(row)
            
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    main()
