from pydantic import BaseModel, EmailStr
from typing import Optional, Any, Dict, List
from datetime import datetime

class LoginRequest(BaseModel):
    email: str
    password: str

class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    role: str
    is_active: bool
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: str = "USER"

class UserUpdate(BaseModel):
    name: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None

class DashboardMovement(BaseModel):
    product_tag: str
    movement_type: str
    change_karat: int
    change_cent: int
    applicable_price_per_karat: str
    total_value: str
    changed_at: datetime

class DashboardMetrics(BaseModel):
    current_stock_worth: str
    stock_added_value: str
    stock_subtracted_value: str
    movements: List[DashboardMovement]

class StockCreate(BaseModel):
    stock_category: str
    stock_type: Optional[str] = None
    product_tag: str
    vvs_white: Optional[str] = None
    hawai_vvs: Optional[str] = None
    quality_cat_1: Optional[str] = None
    quality_cat_2: Optional[str] = None
    quality_cat_3: Optional[str] = None

    karat: int
    cent: int
    price_per_karat: str
class StockVersionUpdate(BaseModel):
    new_karat: str
    reason: Optional[str] = None

class StockResponse(BaseModel):
    id: str
    stock_tag: str
    version_no: int
    is_latest: bool
    stock_category: Optional[str] = None
    stock_type: Optional[str] = None
    product_tag: str
    vvs_white: Optional[str] = None
    hawai_vvs: Optional[str] = None
    quality_cat_1: Optional[str] = None
    quality_cat_2: Optional[str] = None
    quality_cat_3: Optional[str] = None

    karat: int
    cent: int
    current_price_per_karat: str
    base_total_amount: str

    final_price_per_karat: Optional[str] = None

    status: str
    stock_date: datetime
    display_order: int
    created_by: str
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True, "coerce_numbers_to_str": True}

class StockReorderRequest(BaseModel):
    stock_ids: List[str]

class StockKaratUpdate(BaseModel):
    new_karat: str
    reason: Optional[str] = None

class StockPriceUpdate(BaseModel):
    new_price_per_karat: str
    reason: Optional[str] = None

class StockKaratMovementResponse(BaseModel):
    id: str
    stock_id: str
    previous_karat: int
    previous_cent: int
    change_karat: int
    change_cent: int
    new_karat: int
    new_cent: int
    movement_type: str
    applicable_price_per_karat: str
    reason: Optional[str] = None
    changed_by: str
    changed_at: datetime
    
    model_config = {"from_attributes": True}

class StockPriceHistoryResponse(BaseModel):
    id: str
    stock_id: str
    previous_price_per_karat: str
    new_price_per_karat: str
    reason: Optional[str] = None
    changed_by: str
    changed_at: datetime
    
    model_config = {"from_attributes": True}

class StockHistoryResponse(BaseModel):
    movements: List[StockKaratMovementResponse]
    price_history: List[StockPriceHistoryResponse]

class DailyStockKaratMovementResponse(StockKaratMovementResponse):
    product_tag: str

class DailyStockPriceChangeResponse(StockPriceHistoryResponse):
    product_tag: str

class DailyStockHistoryResponse(BaseModel):
    date: str
    added_karat: str
    removed_karat: str
    karat_movements: List[DailyStockKaratMovementResponse]
    price_changes: List[DailyStockPriceChangeResponse]

class RejectionCreate(BaseModel):
    stock_id: str
    rejection_date: str
    sold_karat: int
    sold_cent: int
    sold_price: str
    buyer: Optional[str] = None
    out_remark: Optional[str] = None

class RejectionUpdate(BaseModel):
    out_remark: Optional[str] = None
    buyer: Optional[str] = None
    rejection_date: Optional[str] = None
    sold_price: Optional[str] = None

class RejectionResponse(BaseModel):
    id: str
    stock_id: str
    stock_tag: Optional[str] = None
    stock_category: Optional[str] = None
    stock_type: Optional[str] = None
    product_tag: str
    rejection_date: datetime
    sold_karat: int
    sold_cent: int
    sold_price: str
    original_price_per_karat: str
    total_price: str
    remaining_karat: Optional[int] = None
    remaining_cent: Optional[int] = None
    buyer: Optional[str] = None
    out_remark: Optional[str] = None
    created_by: str
    created_at: datetime
    
    model_config = {"from_attributes": True, "coerce_numbers_to_str": True}


class StockReportSummary(BaseModel):
    total_records: int
    total_karat: str
    total_value: str

class StockReportResponse(BaseModel):
    summary: StockReportSummary
    records: List[StockResponse]

class RejectionReportSummary(BaseModel):
    total_records: int
    total_sold_karat: str
    total_sold_value: str

class RejectionReportResponse(BaseModel):
    summary: RejectionReportSummary
    records: List[RejectionResponse]
