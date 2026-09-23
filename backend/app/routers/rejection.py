from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import decimal
import uuid
from .. import schemas, models, dependencies
from ..dependencies import get_db
from ..tz_utils import ist_now

router = APIRouter(prefix="/api/v1/rejections", tags=["rejections"])

def _to_decimal(val: str) -> decimal.Decimal:
    try:
        return decimal.Decimal(val)
    except decimal.InvalidOperation:
        raise HTTPException(status_code=400, detail=f"Invalid numeric value: {val}")

@router.post("/", response_model=schemas.RejectionResponse)
def create_rejection(
    rejection_in: schemas.RejectionCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    try:
        rej_date = datetime.strptime(rejection_in.rejection_date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")

    # 1. Fetch & lock stock
    stock = db.query(models.Stock).filter(
        models.Stock.id == rejection_in.stock_id,
        models.Stock.is_latest == True
    ).with_for_update().first()
    
    if not stock:
        raise HTTPException(status_code=404, detail="Stock not found or not latest version")

    if stock.status != "AVAILABLE":
        raise HTTPException(status_code=400, detail=f"Stock is not available (current status: {stock.status})")

    available_cents_total = stock.karat * 100 + stock.cent
    sold_cents_total = rejection_in.sold_karat * 100 + rejection_in.sold_cent
    
    if sold_cents_total <= 0:
        raise HTTPException(status_code=400, detail="Sold amount must be greater than zero")
        
    if sold_cents_total > available_cents_total:
        raise HTTPException(status_code=400, detail="Sold amount cannot exceed available stock")

    remaining_cents_total = available_cents_total - sold_cents_total
    remaining_karat = remaining_cents_total // 100
    remaining_cent = remaining_cents_total % 100

    # 2. Calculate values
    sold_price = _to_decimal(rejection_in.sold_price)
    original_price = stock.current_price_per_karat
    
    sold_effective_karat = decimal.Decimal(rejection_in.sold_karat) + decimal.Decimal(rejection_in.sold_cent) / decimal.Decimal('100')
    total_price = sold_effective_karat * sold_price

    # 3. Create rejection record
    new_rejection = models.Rejection(
        id=str(uuid.uuid4()),
        stock_id=stock.id,
        stock_tag=stock.stock_tag,
        stock_category=stock.stock_category,
        stock_type=stock.stock_type,
        product_tag=stock.product_tag,
        rejection_date=rej_date,
        sold_karat=rejection_in.sold_karat,
        sold_cent=rejection_in.sold_cent,
        sold_price=sold_price,
        original_price_per_karat=original_price,
        total_price=total_price,
        remaining_karat=remaining_karat,
        remaining_cent=remaining_cent,
        buyer=rejection_in.buyer,
        out_remark=rejection_in.out_remark,
        created_by=current_user.id
    )
    
    db.add(new_rejection)

    # 4. Update Stock version chain
    stock.is_latest = False
    new_stock_id = str(uuid.uuid4())
    
    # Calculate new base total for remaining stock
    remaining_effective_karat = decimal.Decimal(remaining_karat) + decimal.Decimal(remaining_cent) / decimal.Decimal('100')
    new_base_total = original_price * remaining_effective_karat

    # Determine status if fully sold
    new_status = "SOLD_OUT" if remaining_cents_total == 0 else stock.status

    new_stock = models.Stock(
        id=new_stock_id,
        stock_tag=stock.stock_tag,
        version_no=stock.version_no + 1,
        is_latest=True,
        updated_from_id=stock.id,
        stock_category=stock.stock_category,
        stock_type=stock.stock_type,
        product_tag=stock.product_tag,
        vvs_white=stock.vvs_white,
        hawai_vvs=stock.hawai_vvs,
        quality_cat_1=stock.quality_cat_1,
        quality_cat_2=stock.quality_cat_2,
        quality_cat_3=stock.quality_cat_3,
        karat=remaining_karat,
        cent=remaining_cent,
        current_price_per_karat=original_price,
        base_total_amount=new_base_total,
        final_price_per_karat=stock.final_price_per_karat,
        status=new_status,
        stock_date=stock.stock_date,
        created_by=current_user.id
    )
    db.add(new_stock)

    # 5. Create Movement Log
    movement = models.StockKaratMovement(
        id=str(uuid.uuid4()),
        stock_id=new_stock_id,
        previous_karat=stock.karat,
        previous_cent=stock.cent,
        change_karat=rejection_in.sold_karat,
        change_cent=rejection_in.sold_cent,
        new_karat=remaining_karat,
        new_cent=remaining_cent,
        movement_type="REMOVED",
        applicable_price_per_karat=stock.final_price_per_karat or decimal.Decimal('0'),
        reason="Rejection / Sale",
        changed_by=current_user.id,
        changed_at=ist_now()
    )
    db.add(movement)

    # Commit all atomically
    db.commit()
    db.refresh(new_rejection)
    
    return _build_response(new_rejection)

@router.get("/", response_model=List[schemas.RejectionResponse])
def get_rejections(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    rejections = db.query(models.Rejection).order_by(models.Rejection.rejection_date.desc(), models.Rejection.created_at.desc()).all()
    return [_build_response(r) for r in rejections]

def _build_response(r: models.Rejection) -> schemas.RejectionResponse:
    return schemas.RejectionResponse(
        id=r.id,
        stock_id=r.stock_id,
        stock_tag=r.stock_tag,
        stock_category=r.stock_category,
        stock_type=r.stock_type,
        product_tag=r.product_tag,
        rejection_date=r.rejection_date,
        sold_karat=r.sold_karat,
        sold_cent=r.sold_cent,
        sold_price=str(r.sold_price),
        original_price_per_karat=str(r.original_price_per_karat),
        total_price=str(r.total_price),
        remaining_karat=r.remaining_karat,
        remaining_cent=r.remaining_cent,
        buyer=r.buyer,
        created_by=r.created_by,
        created_at=r.created_at
    )
