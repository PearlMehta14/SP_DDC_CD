import sys
import os
from sqlalchemy import text

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import engine

def run():
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE rejections ADD COLUMN status VARCHAR DEFAULT 'ACTIVE'"))
            conn.commit()
            print("Successfully added status column to rejections table.")
        except Exception as e:
            print(f"Error (column might already exist): {e}")

if __name__ == "__main__":
    run()
