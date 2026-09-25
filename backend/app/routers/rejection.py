from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
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

@router.put("/{id}", response_model=schemas.RejectionResponse)
def update_rejection(
    id: str,
    rejection_in: schemas.RejectionUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    rejection = db.query(models.Rejection).filter(models.Rejection.id == id).first()
    if not rejection:
        raise HTTPException(status_code=404, detail="Rejection not found")

    if rejection_in.out_remark is not None:
        rejection.out_remark = rejection_in.out_remark
    if rejection_in.buyer is not None:
        rejection.buyer = rejection_in.buyer
    if rejection_in.rejection_date is not None:
        try:
            rejection.rejection_date = datetime.strptime(rejection_in.rejection_date, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    if rejection_in.sold_price is not None:
        rejection.sold_price = _to_decimal(rejection_in.sold_price)
        sold_effective_karat = decimal.Decimal(rejection.sold_karat) + decimal.Decimal(rejection.sold_cent) / decimal.Decimal('100')
        rejection.total_price = sold_effective_karat * rejection.sold_price

    db.commit()
    db.refresh(rejection)
    return _build_response(rejection)

@router.delete("/{id}")
def delete_rejection(
    id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    rejection = db.query(models.Rejection).filter(models.Rejection.id == id).first()
    if not rejection:
        raise HTTPException(status_code=404, detail="Rejection not found")

    # Find the current latest stock for this product
    latest_stock = db.query(models.Stock).filter(
        models.Stock.product_tag == rejection.product_tag,
        models.Stock.stock_category == rejection.stock_category,
        models.Stock.stock_type == rejection.stock_type,
        models.Stock.is_latest == True
    ).with_for_update().first()

    if latest_stock:
        # Restore stock
        restored_cents_total = latest_stock.karat * 100 + latest_stock.cent + rejection.sold_karat * 100 + rejection.sold_cent
        restored_karat = restored_cents_total // 100
        restored_cent = restored_cents_total % 100
        
        latest_stock.is_latest = False
        
        restored_effective_karat = decimal.Decimal(restored_karat) + decimal.Decimal(restored_cent) / decimal.Decimal('100')
        new_base_total = latest_stock.current_price_per_karat * restored_effective_karat
        
        new_stock = models.Stock(
            id=str(uuid.uuid4()),
            stock_tag=latest_stock.stock_tag,
            version_no=latest_stock.version_no + 1,
            is_latest=True,
            updated_from_id=latest_stock.id,
            stock_category=latest_stock.stock_category,
            stock_type=latest_stock.stock_type,
            product_tag=latest_stock.product_tag,
            vvs_white=latest_stock.vvs_white,
            hawai_vvs=latest_stock.hawai_vvs,
            quality_cat_1=latest_stock.quality_cat_1,
            quality_cat_2=latest_stock.quality_cat_2,
            quality_cat_3=latest_stock.quality_cat_3,
            karat=restored_karat,
            cent=restored_cent,
            current_price_per_karat=latest_stock.current_price_per_karat,
            base_total_amount=new_base_total,
            final_price_per_karat=latest_stock.final_price_per_karat,
            status="AVAILABLE",
            stock_date=latest_stock.stock_date,
            created_by=current_user.id
        )
        db.add(new_stock)
        
        movement = models.StockKaratMovement(
            id=str(uuid.uuid4()),
            stock_id=new_stock.id,
            previous_karat=latest_stock.karat,
            previous_cent=latest_stock.cent,
            change_karat=rejection.sold_karat,
            change_cent=rejection.sold_cent,
            new_karat=restored_karat,
            new_cent=restored_cent,
            movement_type="ADDED",
            applicable_price_per_karat=latest_stock.final_price_per_karat or decimal.Decimal('0'),
            reason="Rejection Deleted",
            changed_by=current_user.id,
            changed_at=ist_now()
        )
        db.add(movement)

    db.delete(rejection)
    db.commit()
    return {"status": "success"}

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
        out_remark=r.out_remark,
        created_by=r.created_by,
        created_at=r.created_at
    )
