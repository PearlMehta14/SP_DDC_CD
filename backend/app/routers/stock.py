from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
import decimal
import uuid
from .. import schemas, models, dependencies
from ..dependencies import get_db
from ..tz_utils import ist_now

router = APIRouter(prefix="/api/v1/stock", tags=["stock"])

def _to_decimal(val: Optional[str], default: Optional[str] = None) -> Optional[decimal.Decimal]:
    v = val if val and val.strip() else default
    if not v:
        return None
    try:
        return decimal.Decimal(v)
    except decimal.InvalidOperation:
        raise HTTPException(status_code=400, detail=f"Invalid numeric value: {v}")

def _from_decimal(val: Optional[decimal.Decimal]) -> Optional[str]:
    if val is None:
        return None
    return str(val)

def calculate_stock_fields(
    price_per_karat: decimal.Decimal,
    karat: decimal.Decimal
):
    base_total = price_per_karat * karat

    return {
        "base_total_amount": base_total,
        "final_price_per_karat": price_per_karat
    }

@router.post("/", response_model=schemas.StockResponse)
def create_stock(
    stock_in: schemas.StockCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    """Upsert stock: if a record already exists with the same product_tag + category + type, update it; otherwise create new."""
    price = _to_decimal(stock_in.price_per_karat)
    karat_int = stock_in.karat
    cent_int = stock_in.cent
    effective_karat = decimal.Decimal(karat_int) + decimal.Decimal(cent_int) / decimal.Decimal('100')
    calcs = calculate_stock_fields(price, effective_karat)
    now = ist_now()

    # --- UPSERT LOGIC ---
    # Check for an existing AVAILABLE, is_latest record with the same natural key
    existing_query = (
        db.query(models.Stock)
        .filter(
            models.Stock.is_latest == True,
            models.Stock.status == "AVAILABLE",
            models.Stock.product_tag == stock_in.product_tag,
            models.Stock.stock_category == stock_in.stock_category,
        )
    )
    if stock_in.stock_type:
        existing_query = existing_query.filter(models.Stock.stock_type == stock_in.stock_type)
    else:
        existing_query = existing_query.filter(models.Stock.stock_type == None)

    existing = existing_query.first()

    if existing is not None:
        # UPDATE the existing record in-place
        old_karat = existing.karat
        old_cent = existing.cent
        existing.karat = karat_int
        existing.cent = cent_int
        existing.current_price_per_karat = price
        existing.base_total_amount = calcs['base_total_amount']
        existing.final_price_per_karat = calcs['final_price_per_karat']

        old_cents_total = old_karat * 100 + old_cent
        new_cents_total = karat_int * 100 + cent_int
        diff = new_cents_total - old_cents_total
        movement_type = 'ADDED' if diff >= 0 else 'REMOVED'
        change_cents_total = abs(diff)

        movement = models.StockKaratMovement(
            id=str(uuid.uuid4()),
            stock_id=existing.id,
            previous_karat=old_karat,
            previous_cent=old_cent,
            change_karat=change_cents_total // 100,
            change_cent=change_cents_total % 100,
            new_karat=karat_int,
            new_cent=cent_int,
            movement_type=movement_type,
            applicable_price_per_karat=calcs['final_price_per_karat'] or decimal.Decimal('0'),
            reason="Stock batch update (upsert)",
            changed_by=current_user.id,
            changed_at=now,
        )
        db.add(movement)
        db.commit()
        db.refresh(existing)
        return _build_response(existing)

    # --- CREATE NEW ---
    stock_id = str(uuid.uuid4())

    new_stock = models.Stock(
        id=stock_id,
        stock_tag=stock_id,
        version_no=0,
        is_latest=True,
        stock_category=stock_in.stock_category,
        stock_type=stock_in.stock_type,
        product_tag=stock_in.product_tag,
        vvs_white=stock_in.vvs_white,
        hawai_vvs=stock_in.hawai_vvs,
        quality_cat_1=stock_in.quality_cat_1,
        quality_cat_2=stock_in.quality_cat_2,
        quality_cat_3=stock_in.quality_cat_3,
        karat=karat_int,
        cent=cent_int,
        current_price_per_karat=price,
        base_total_amount=calcs['base_total_amount'],
        final_price_per_karat=calcs['final_price_per_karat'],
        status="AVAILABLE",
        stock_date=now,
        created_by=current_user.id
    )
    
    db.add(new_stock)
    
    movement = models.StockKaratMovement(
        id=str(uuid.uuid4()),
        stock_id=stock_id,
        previous_karat=0,
        previous_cent=0,
        change_karat=karat_int,
        change_cent=cent_int,
        new_karat=karat_int,
        new_cent=cent_int,
        movement_type="ADDED",
        applicable_price_per_karat=calcs['final_price_per_karat'] or decimal.Decimal('0'),
        reason="Initial Stock Entry",
        changed_by=current_user.id,
        changed_at=now
    )
    db.add(movement)
    
    db.commit()
    db.refresh(new_stock)
    
    return _build_response(new_stock)


@router.get("/", response_model=List[schemas.StockResponse])
def get_stock(
    q: Optional[str] = Query(None, description="Search by product tag"),
    category: Optional[str] = Query(None, description="Filter by category"),
    quality: Optional[str] = Query(None, description="Filter by quality"),
    karat: Optional[str] = Query(None, description="Filter by karat"),
    status: Optional[str] = Query("AVAILABLE", description="Filter by status"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    query = db.query(models.Stock)
    
    query = query.filter(models.Stock.is_latest == True)
    
    if category and category.upper() != "ALL":
        query = query.filter(models.Stock.stock_category == category.upper())
        
    if status and status.upper() != "ALL":
        query = query.filter(models.Stock.status == status.upper())
        
    if q:
        query = query.filter(models.Stock.product_tag.ilike(f"%{q}%"))
        
    if quality:
        # Check either vvs_white or hawai_vvs
        query = query.filter((models.Stock.vvs_white == quality) | (models.Stock.hawai_vvs == quality))
        
    if karat:
        try:
            karat_val = decimal.Decimal(karat)
            query = query.filter(models.Stock.karat == karat_val)
        except decimal.InvalidOperation:
            pass
    
    stocks = query.order_by(models.Stock.display_order.desc(), models.Stock.created_at.desc()).all()
    return [_build_response(s) for s in stocks]

@router.put("/reorder")
def reorder_stocks(
    req: schemas.StockReorderRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    total = len(req.stock_ids)
    for idx, sid in enumerate(req.stock_ids):
        # We assign length - idx to display_order. 
        # e.g. top item gets N, bottom item gets 1
        stock = db.query(models.Stock).filter(models.Stock.id == sid, models.Stock.is_latest == True).first()
        if stock:
            stock.display_order = total - idx
    db.commit()
    return {"status": "success"}

@router.get("/history", response_model=schemas.DailyStockHistoryResponse)
def get_stock_history_by_date(
    date: str = Query(..., description="Date in YYYY-MM-DD format"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    try:
        target_date = datetime.strptime(date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
        
    # Query stock karat movements
    movements_query = db.query(models.StockKaratMovement, models.Stock.product_tag).join(
        models.Stock, models.Stock.id == models.StockKaratMovement.stock_id
    ).filter(
        func.date(models.StockKaratMovement.changed_at) == target_date
    ).order_by(models.StockKaratMovement.changed_at.desc()).all()
    
    added_k = decimal.Decimal('0')
    removed_k = decimal.Decimal('0')
    daily_movements = []
    
    for movement, tag in movements_query:
        effective_change = decimal.Decimal(movement.change_karat) + decimal.Decimal(movement.change_cent) / decimal.Decimal('100')
        if movement.movement_type == 'ADDED':
            added_k += effective_change
        elif movement.movement_type == 'REMOVED':
            removed_k += effective_change
            
        # Build DailyStockKaratMovementResponse
        resp = schemas.DailyStockKaratMovementResponse(
            id=movement.id,
            stock_id=movement.stock_id,
            previous_karat=movement.previous_karat,
            previous_cent=movement.previous_cent,
            change_karat=movement.change_karat,
            change_cent=movement.change_cent,
            new_karat=movement.new_karat,
            new_cent=movement.new_cent,
            movement_type=movement.movement_type,
            applicable_price_per_karat=str(movement.applicable_price_per_karat),
            reason=movement.reason,
            changed_by=movement.changed_by,
            changed_at=movement.changed_at,
            product_tag=tag
        )
        daily_movements.append(resp)
        
    # Query price changes
    price_query = db.query(models.StockPriceHistory, models.Stock.product_tag).join(
        models.Stock, models.Stock.id == models.StockPriceHistory.stock_id
    ).filter(
        func.date(models.StockPriceHistory.changed_at) == target_date
    ).order_by(models.StockPriceHistory.changed_at.desc()).all()
    
    daily_price_changes = []
    for price_change, tag in price_query:
        resp = schemas.DailyStockPriceChangeResponse(
            id=price_change.id,
            stock_id=price_change.stock_id,
            previous_price_per_karat=str(price_change.previous_price_per_karat),
            new_price_per_karat=str(price_change.new_price_per_karat),
            reason=price_change.reason,
            changed_by=price_change.changed_by,
            changed_at=price_change.changed_at,
            product_tag=tag
        )
        daily_price_changes.append(resp)
        
    return schemas.DailyStockHistoryResponse(
        date=date,
        added_karat=str(added_k),
        removed_karat=str(removed_k),
        karat_movements=daily_movements,
        price_changes=daily_price_changes
    )


@router.post("/{stock_id}/version", response_model=schemas.StockResponse)
def create_stock_version(
    stock_id: str,
    update_in: schemas.StockVersionUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    old_stock = db.query(models.Stock).filter(models.Stock.id == stock_id, models.Stock.is_latest == True).first()
    if not old_stock:
        raise HTTPException(status_code=404, detail="Current stock version not found")
        
    old_cents_total = old_stock.karat * 100 + old_stock.cent
    try:
        val = decimal.Decimal(update_in.new_karat)
    except decimal.InvalidOperation:
        raise HTTPException(status_code=400, detail="Invalid new_karat value")
        
    new_cents_total = int(val * 100)
    diff = new_cents_total - old_cents_total
    
    if diff == 0:
        return _build_response(old_stock) # No changes
        
    if new_cents_total < 0:
        raise HTTPException(status_code=400, detail="Stock karat cannot be less than zero.")
        
    new_karat = new_cents_total // 100
    new_cent = new_cents_total % 100
    
    # Mark old stock as not latest
    old_stock.is_latest = False
    
    new_stock_id = str(uuid.uuid4())
    effective_karat = decimal.Decimal(new_karat) + decimal.Decimal(new_cent) / decimal.Decimal('100')
    
    calcs = calculate_stock_fields(
        old_stock.current_price_per_karat,
        effective_karat
    )
    
    new_stock = models.Stock(
        id=new_stock_id,
        stock_tag=old_stock.stock_tag,
        version_no=old_stock.version_no + 1,
        is_latest=True,
        updated_from_id=old_stock.id,
        stock_category=old_stock.stock_category,
        stock_type=old_stock.stock_type,
        product_tag=old_stock.product_tag,
        vvs_white=old_stock.vvs_white,
        hawai_vvs=old_stock.hawai_vvs,
        quality_cat_1=old_stock.quality_cat_1,
        quality_cat_2=old_stock.quality_cat_2,
        quality_cat_3=old_stock.quality_cat_3,
        karat=new_karat,
        cent=new_cent,
        current_price_per_karat=old_stock.current_price_per_karat,
        base_total_amount=calcs['base_total_amount'],
        final_price_per_karat=old_stock.final_price_per_karat,
        status=old_stock.status,
        stock_date=old_stock.stock_date,
        created_by=current_user.id
    )
    
    # Movement log for history
    movement_type = 'ADDED' if diff > 0 else 'REMOVED'
    change_cents_total = abs(diff)
    
    movement = models.StockKaratMovement(
        id=str(uuid.uuid4()),
        stock_id=new_stock_id,
        previous_karat=old_stock.karat,
        previous_cent=old_stock.cent,
        change_karat=change_cents_total // 100,
        change_cent=change_cents_total % 100,
        new_karat=new_karat,
        new_cent=new_cent,
        movement_type=movement_type,
        applicable_price_per_karat=old_stock.final_price_per_karat or decimal.Decimal('0'),
        reason=update_in.reason or "Version update",
        changed_by=current_user.id,
        changed_at=ist_now()
    )
    
    db.add(new_stock)
    db.add(movement)
    db.commit()
    db.refresh(new_stock)
    
    return _build_response(new_stock)

@router.get("/logs")
def get_all_movement_logs(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    """Return all karat movement logs across all stocks, newest first."""
    movements_orm = (
        db.query(models.StockKaratMovement, models.Stock, models.User)
        .join(models.Stock, models.StockKaratMovement.stock_id == models.Stock.id)
        .outerjoin(models.User, models.StockKaratMovement.changed_by == models.User.id)
        .order_by(models.StockKaratMovement.changed_at.desc())
        .all()
    )
    result = []
    for m, s, u in movements_orm:
        result.append({
            "id": m.id,
            "stock_id": m.stock_id,
            "stock_category": s.stock_category,
            "stock_type": s.stock_type,
            "product_tag": s.product_tag,
            "previous_karat": m.previous_karat,
            "previous_cent": m.previous_cent,
            "change_karat": m.change_karat,
            "change_cent": m.change_cent,
            "new_karat": m.new_karat,
            "new_cent": m.new_cent,
            "movement_type": m.movement_type,
            "reason": m.reason,
            "changed_by_id": m.changed_by,
            "changed_by_name": u.name if u else "Unknown",
            "changed_by_email": u.email if u else None,
            "changed_at": m.changed_at.isoformat() if m.changed_at else None,
        })
    return result

@router.get("/{stock_id}", response_model=schemas.StockResponse)
def get_stock_by_id(
    stock_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    stock = db.query(models.Stock).filter(models.Stock.id == stock_id).first()
    if not stock:
        raise HTTPException(status_code=404, detail="Stock not found")
    return _build_response(stock)

@router.post("/{stock_id}/karat", response_model=schemas.StockResponse)
def update_stock_karat(
    stock_id: str,
    update_in: schemas.StockKaratUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    stock = db.query(models.Stock).filter(models.Stock.id == stock_id).first()
    if not stock:
        raise HTTPException(status_code=404, detail="Stock not found")
        
    old_karat = stock.karat
    old_cent = stock.cent
    old_cents_total = old_karat * 100 + old_cent
    
    try:
        val = decimal.Decimal(update_in.new_karat)
    except decimal.InvalidOperation:
        raise HTTPException(status_code=400, detail="Invalid new_karat value")
        
    new_cents_total = int(val * 100)
    diff = new_cents_total - old_cents_total
    
    if diff == 0:
        return _build_response(stock)
        
    if diff > 0:
        movement_type = 'ADDED'
        change_cents_total = diff
    else:
        movement_type = 'REMOVED'
        change_cents_total = -diff
        
    change_karat = change_cents_total // 100
    change_cent = change_cents_total % 100
        
    if new_cents_total < 0:
        raise HTTPException(status_code=400, detail="Stock karat cannot be less than zero.")
        
    new_karat = new_cents_total // 100
    new_cent = new_cents_total % 100
    
    # Update current karat and cent
    stock.karat = new_karat
    stock.cent = new_cent
    
    effective_karat = decimal.Decimal(new_karat) + decimal.Decimal(new_cent) / decimal.Decimal('100')
    
    calcs = calculate_stock_fields(
        stock.current_price_per_karat,
        effective_karat
    )
    stock.base_total_amount = calcs['base_total_amount']
    
    applicable_price = stock.final_price_per_karat or decimal.Decimal('0')
    
    # Record movement
    movement = models.StockKaratMovement(
        id=str(uuid.uuid4()),
        stock_id=stock_id,
        previous_karat=old_karat,
        previous_cent=old_cent,
        change_karat=change_karat,
        change_cent=change_cent,
        new_karat=new_karat,
        new_cent=new_cent,
        movement_type=movement_type,
        applicable_price_per_karat=applicable_price,
        reason=update_in.reason or "Manual adjustment",
        changed_by=current_user.id,
        changed_at=ist_now()
    )
    db.add(movement)
    db.commit()
    db.refresh(stock)
    
    return _build_response(stock)

@router.post("/{stock_id}/price", response_model=schemas.StockResponse)
def update_stock_price(
    stock_id: str,
    update_in: schemas.StockPriceUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    stock = db.query(models.Stock).filter(models.Stock.id == stock_id).first()
    if not stock:
        raise HTTPException(status_code=404, detail="Stock not found")
        
    old_price = stock.current_price_per_karat
    new_price = _to_decimal(update_in.new_price_per_karat)
    
    if old_price == new_price:
        return _build_response(stock)
        
    # Update price
    stock.current_price_per_karat = new_price
    
    effective_karat = decimal.Decimal(stock.karat) + decimal.Decimal(stock.cent) / decimal.Decimal('100')
    
    calcs = calculate_stock_fields(
        stock.current_price_per_karat,
        effective_karat
    )
    stock.base_total_amount = calcs['base_total_amount']
    stock.final_price_per_karat = calcs['final_price_per_karat']
    
    # Record price history
    history = models.StockPriceHistory(
        id=str(uuid.uuid4()),
        stock_id=stock_id,
        previous_price_per_karat=old_price,
        new_price_per_karat=new_price,
        reason=update_in.reason or "Manual adjustment",
        changed_by=current_user.id,
        changed_at=ist_now()
    )
    db.add(history)
    db.commit()
    db.refresh(stock)
    
    return _build_response(stock)

@router.get("/{stock_id}/history", response_model=schemas.StockHistoryResponse)
def get_stock_history(
    stock_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(dependencies.get_current_user)
):
    movements_orm = db.query(models.StockKaratMovement).filter(models.StockKaratMovement.stock_id == stock_id).order_by(models.StockKaratMovement.changed_at.desc()).all()
    price_history_orm = db.query(models.StockPriceHistory).filter(models.StockPriceHistory.stock_id == stock_id).order_by(models.StockPriceHistory.changed_at.desc()).all()
    
    movements = []
    for m in movements_orm:
        movements.append(schemas.StockKaratMovementResponse(
            id=m.id,
            stock_id=m.stock_id,
            previous_karat=m.previous_karat,
            previous_cent=m.previous_cent,
            change_karat=m.change_karat,
            change_cent=m.change_cent,
            new_karat=m.new_karat,
            new_cent=m.new_cent,
            movement_type=m.movement_type,
            applicable_price_per_karat=str(m.applicable_price_per_karat),
            reason=m.reason,
            changed_by=m.changed_by,
            changed_at=m.changed_at
        ))
        
    price_history = []
    for p in price_history_orm:
        price_history.append(schemas.StockPriceHistoryResponse(
            id=p.id,
            stock_id=p.stock_id,
            previous_price_per_karat=str(p.previous_price_per_karat),
            new_price_per_karat=str(p.new_price_per_karat),
            reason=p.reason,
            changed_by=p.changed_by,
            changed_at=p.changed_at
        ))
    
    return schemas.StockHistoryResponse(
        movements=movements,
        price_history=price_history
    )


def _build_response(s: models.Stock) -> schemas.StockResponse:
    return schemas.StockResponse(
        id=s.id,
        stock_tag=s.stock_tag,
        version_no=s.version_no,
        is_latest=s.is_latest,
        stock_category=s.stock_category,
        stock_type=s.stock_type,
        product_tag=s.product_tag,
        vvs_white=s.vvs_white,
        hawai_vvs=s.hawai_vvs,
        quality_cat_1=s.quality_cat_1,
        quality_cat_2=s.quality_cat_2,
        quality_cat_3=s.quality_cat_3,
        karat=s.karat,
        cent=s.cent,
        current_price_per_karat=_from_decimal(s.current_price_per_karat) or "0",
        base_total_amount=_from_decimal(s.base_total_amount) or "0",
        final_price_per_karat=_from_decimal(s.final_price_per_karat),
        status=s.status,
        stock_date=s.stock_date,
        display_order=s.display_order,
        created_by=s.created_by,
        created_at=s.created_at,
        updated_at=s.updated_at
    )
