from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime, date, timedelta
import decimal

from .. import schemas, models, dependencies
from ..dependencies import get_db
from ..tz_utils import ist_now

router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])

def get_dashboard_metrics(db: Session, target_date: date):
    target_datetime_start = datetime.combine(target_date, datetime.min.time())
    target_datetime_end = target_datetime_start + timedelta(days=1)
    
    # Current available stock (always current, regardless of selected date)
    stocks = db.query(models.Stock).filter(
        models.Stock.status == "AVAILABLE",
        models.Stock.is_latest == True
    ).all()
    
    current_stock_worth = decimal.Decimal('0')
    
    for s in stocks:
        effective_weight = decimal.Decimal(s.karat) + decimal.Decimal(s.cent) / decimal.Decimal('100')
        val = effective_weight * (s.final_price_per_karat or decimal.Decimal('0'))
        current_stock_worth += val
        
    # Rejections total
    from sqlalchemy.sql import func
    total_rejection_worth = db.query(func.sum(models.Rejection.total_price)).scalar() or decimal.Decimal('0')
    current_stock_worth += decimal.Decimal(total_rejection_worth)
            
    # Movements for the target date
    stock_added_value = decimal.Decimal('0')
    stock_subtracted_value = decimal.Decimal('0')
    
    movements_query = db.query(models.StockKaratMovement, models.Stock.product_tag).join(
        models.Stock, models.Stock.id == models.StockKaratMovement.stock_id
    ).filter(
        models.StockKaratMovement.changed_at >= target_datetime_start,
        models.StockKaratMovement.changed_at < target_datetime_end
    ).order_by(models.StockKaratMovement.changed_at.desc()).all()
    
    movements = []
    
    for m, tag in movements_query:
        effective_change = decimal.Decimal(m.change_karat) + decimal.Decimal(m.change_cent) / decimal.Decimal('100')
        movement_value = effective_change * m.applicable_price_per_karat
        
        if m.movement_type == 'ADDED':
            stock_added_value += movement_value
        elif m.movement_type == 'REMOVED':
            stock_subtracted_value += movement_value
            
        movements.append(schemas.DashboardMovement(
            product_tag=tag,
            movement_type=m.movement_type,
            change_karat=m.change_karat,
            change_cent=m.change_cent,
            applicable_price_per_karat=str(m.applicable_price_per_karat),
            total_value=str(movement_value),
            changed_at=m.changed_at
        ))

    return schemas.DashboardMetrics(
        current_stock_worth=str(current_stock_worth),
        stock_added_value=str(stock_added_value),
        stock_subtracted_value=str(stock_subtracted_value),
        movements=movements
    )

@router.get("/today", response_model=schemas.DashboardMetrics)
def get_dashboard_today(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    return get_dashboard_metrics(db, ist_now().date())

@router.get("/", response_model=schemas.DashboardMetrics)
def get_dashboard_by_date(
    date: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    try:
        target_date = datetime.strptime(date, "%Y-%m-%d").date()
    except ValueError:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
        
    return get_dashboard_metrics(db, target_date)
