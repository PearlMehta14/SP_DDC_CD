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
        # Find the stock tag of the test entry
        query = text("""
            SELECT stock_tag, id, product_tag 
            FROM stocks 
            WHERE stock_category = 'NEW' 
            AND product_tag ILIKE '%test%'
        """)
        
        result = db.execute(query).fetchall()
        
        if not result:
            print("No matching stock found.")
            return
            
        print(f"Found matches: {result}")
        
        for row in result:
            stock_tag = row[0]
            print(f"Deleting chain for stock_tag: {stock_tag}")
            
            chain_query = text("SELECT id FROM stocks WHERE stock_tag = :tag")
            chain_ids = [r[0] for r in db.execute(chain_query, {"tag": stock_tag}).fetchall()]
            
            if not chain_ids:
                continue
                
            db.execute(text("DELETE FROM rejections WHERE stock_id = ANY(:ids)"), {"ids": chain_ids})
            db.execute(text("DELETE FROM stock_karat_movements WHERE stock_id = ANY(:ids)"), {"ids": chain_ids})
            db.execute(text("DELETE FROM stock_price_history WHERE stock_id = ANY(:ids)"), {"ids": chain_ids})
            db.execute(text("DELETE FROM stocks WHERE stock_tag = :tag"), {"tag": stock_tag})
            
        db.commit()
        print("Successfully hard deleted the mistakenly created NEW test record.")
        
    except Exception as e:
        db.rollback()
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    main()
