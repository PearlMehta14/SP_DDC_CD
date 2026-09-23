from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import Optional
import decimal

from .. import schemas, models, dependencies
from ..dependencies import get_db

router = APIRouter(prefix="/api/v1/reports", tags=["reports"])

@router.get("/stock", response_model=schemas.StockReportResponse)
def get_stock_reports(
    stock_category: Optional[str] = None,
    stock_type: Optional[str] = None,
    product_tag: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    query = db.query(models.Stock).filter(models.Stock.is_latest == True)
    
    if stock_category and stock_category.upper() != "ALL":
        query = query.filter(models.Stock.stock_category == stock_category.upper())
        
    if stock_type and stock_type.upper() != "ALL":
        # EXTRA category ignores type
        if not (stock_category and stock_category.upper() == "EXTRA"):
            query = query.filter(models.Stock.stock_type == stock_type)
        
    if product_tag and product_tag.upper() != "ALL":
        query = query.filter(models.Stock.product_tag == product_tag)
        
    query = query.order_by(desc(models.Stock.stock_date), desc(models.Stock.created_at))
    
    stocks = query.all()
    
    total_karat = decimal.Decimal('0')
    total_value = decimal.Decimal('0')
    
    records = []
    for s in stocks:
        effective_weight = decimal.Decimal(s.karat) + decimal.Decimal(s.cent) / decimal.Decimal('100')
        total_karat += effective_weight
        total_value += s.base_total_amount # Wait, the user said "sum of the appropriate final/current value according to the existing stock calculation". We have final_total_amount? No, we removed LESS/BROKERAGE from individual rows! So base_total_amount IS the final amount for the row!
        
        r_dict = {
            "id": s.id,
            "stock_tag": s.stock_tag,
            "version_no": s.version_no,
            "is_latest": s.is_latest,
            "stock_category": s.stock_category,
            "stock_type": s.stock_type,
            "product_tag": s.product_tag,
            "vvs_white": s.vvs_white,
            "hawai_vvs": s.hawai_vvs,
            "quality_cat_1": s.quality_cat_1,
            "quality_cat_2": s.quality_cat_2,
            "quality_cat_3": s.quality_cat_3,
            "karat": s.karat,
            "cent": s.cent,
            "current_price_per_karat": str(s.current_price_per_karat) if s.current_price_per_karat is not None else None,
            "base_total_amount": str(s.base_total_amount) if s.base_total_amount is not None else None,
            "final_price_per_karat": str(s.final_price_per_karat) if s.final_price_per_karat is not None else None,
            "status": s.status,
            "stock_date": s.stock_date,
            "created_by": s.created_by,
            "created_at": s.created_at,
            "updated_at": s.updated_at
        }
        records.append(r_dict)
        
    summary = schemas.StockReportSummary(
        total_records=len(stocks),
        total_karat=str(total_karat),
        total_value=str(total_value)
    )
    
    return {"summary": summary, "records": records}

@router.get("/rejection", response_model=schemas.RejectionReportResponse)
def get_rejection_reports(
    stock_category: Optional[str] = None,
    stock_type: Optional[str] = None,
    product_tag: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    query = db.query(models.Rejection)
    
    if stock_category and stock_category.upper() != "ALL":
        query = query.filter(models.Rejection.stock_category == stock_category.upper())
        
    if stock_type and stock_type.upper() != "ALL":
        if not (stock_category and stock_category.upper() == "EXTRA"):
            query = query.filter(models.Rejection.stock_type == stock_type)
        
    if product_tag and product_tag.upper() != "ALL":
        query = query.filter(models.Rejection.product_tag == product_tag)
        
    query = query.order_by(desc(models.Rejection.rejection_date), desc(models.Rejection.created_at))
    
    rejections = query.all()
    
    total_sold_karat = decimal.Decimal('0')
    total_sold_value = decimal.Decimal('0')
    
    records = []
    for r in rejections:
        effective_weight = decimal.Decimal(r.sold_karat) + decimal.Decimal(r.sold_cent) / decimal.Decimal('100')
        total_sold_karat += effective_weight
        total_sold_value += r.total_price # Rejection.total_price is calculated in rejection.py as sold_effective_karat * sold_price
        
        r_dict = {
            "id": r.id,
            "stock_id": r.stock_id,
            "stock_tag": r.stock_tag,
            "stock_category": r.stock_category,
            "stock_type": r.stock_type,
            "product_tag": r.product_tag,
            "rejection_date": r.rejection_date,
            "sold_karat": r.sold_karat,
            "sold_cent": r.sold_cent,
            "sold_price": str(r.sold_price) if r.sold_price is not None else None,
            "original_price_per_karat": str(r.original_price_per_karat) if r.original_price_per_karat is not None else None,
            "total_price": str(r.total_price) if r.total_price is not None else None,
            "remaining_karat": r.remaining_karat,
            "remaining_cent": r.remaining_cent,
            "buyer": r.buyer,
            "created_by": r.created_by,
            "created_at": r.created_at
        }
        records.append(r_dict)
        
    summary = schemas.RejectionReportSummary(
        total_records=len(rejections),
        total_sold_karat=str(total_sold_karat),
        total_sold_value=str(total_sold_value)
    )
    
    return {"summary": summary, "records": records}
