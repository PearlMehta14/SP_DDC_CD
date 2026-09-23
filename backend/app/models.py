from sqlalchemy import Column, String, Boolean, DateTime, Numeric, Integer, ForeignKey, Float, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
from .database import Base
from .tz_utils import ist_now

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True) # References Supabase auth.users.id
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    role = Column(String, default="USER")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=ist_now)
    updated_at = Column(DateTime(timezone=True), default=ist_now, onupdate=ist_now)

class Stock(Base):
    __tablename__ = "stocks"

    id = Column(String, primary_key=True, index=True)
    stock_tag = Column(String(36), index=True, nullable=False)
    version_no = Column(Integer, default=0, nullable=False)
    is_latest = Column(Boolean, default=True, index=True, nullable=False)
    updated_from_id = Column(String, ForeignKey("stocks.id"), nullable=True)
    stock_category = Column(String, nullable=True)
    stock_type = Column(String, nullable=True)
    product_tag = Column(String, index=True)
    vvs_white = Column(String)
    hawai_vvs = Column(String)
    quality_cat_1 = Column(String)
    quality_cat_2 = Column(String)
    quality_cat_3 = Column(String)

    karat = Column(Integer, nullable=False)
    cent = Column(Integer, nullable=False, default=0)
    current_price_per_karat = Column(Numeric, nullable=False)
    base_total_amount = Column(Numeric, nullable=False)

    final_price_per_karat = Column(Numeric, nullable=True)

    status = Column(String, default="AVAILABLE")
    stock_date = Column(DateTime(timezone=True), nullable=False)
    created_by = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), default=ist_now)
    updated_at = Column(DateTime(timezone=True), default=ist_now, onupdate=ist_now)

    karat_movements = relationship("StockKaratMovement", back_populates="stock")

class StockKaratMovement(Base):
    __tablename__ = "stock_karat_movements"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    stock_id = Column(String(36), ForeignKey("stocks.id"), nullable=False)
    
    previous_karat = Column(Integer, nullable=False)
    previous_cent = Column(Integer, nullable=False, default=0)
    
    change_karat = Column(Integer, nullable=False)
    change_cent = Column(Integer, nullable=False, default=0)
    
    new_karat = Column(Integer, nullable=False)
    new_cent = Column(Integer, nullable=False, default=0)
    
    movement_type = Column(String, nullable=False) # "ADDED" or "REMOVED"
    applicable_price_per_karat = Column(Numeric, nullable=False)
    
    reason = Column(Text, nullable=True)
    changed_by = Column(String, ForeignKey("users.id"), nullable=False)
    changed_at = Column(DateTime(timezone=True), default=ist_now)

    stock = relationship("Stock", back_populates="karat_movements")
    user = relationship("User")

class StockPriceHistory(Base):
    __tablename__ = "stock_price_history"

    id = Column(String, primary_key=True, index=True)
    stock_id = Column(String, index=True, nullable=False)
    previous_price_per_karat = Column(Numeric, nullable=False)
    new_price_per_karat = Column(Numeric, nullable=False)
    reason = Column(String)
    changed_by = Column(String, nullable=False)
    changed_at = Column(DateTime(timezone=True), default=ist_now)

class Rejection(Base):
    __tablename__ = "rejections"

    id = Column(String, primary_key=True, index=True)
    stock_id = Column(String, index=True, nullable=False)
    stock_tag = Column(String)
    stock_category = Column(String)
    stock_type = Column(String)
    product_tag = Column(String, nullable=False)
    rejection_date = Column(DateTime(timezone=True), nullable=False)
    sold_karat = Column(Integer, nullable=False)
    sold_cent = Column(Integer, nullable=False, default=0)
    sold_price = Column(Numeric, nullable=False)
    original_price_per_karat = Column(Numeric, nullable=False)
    total_price = Column(Numeric, nullable=False)
    remaining_karat = Column(Integer)
    remaining_cent = Column(Integer, default=0)
    buyer = Column(String, nullable=True)
    out_remark = Column(String, nullable=True)
    
    created_by = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), default=ist_now)
