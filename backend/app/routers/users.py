from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from .. import schemas, models, dependencies
from ..dependencies import supabase_admin, get_db

router = APIRouter(prefix="/api/v1/users", tags=["users"])

@router.get("/me", response_model=schemas.UserResponse)
def read_user_me(current_user: models.User = Depends(dependencies.get_current_user)):
    return current_user

@router.get("/", response_model=List[schemas.UserResponse])
def read_users(
    skip: int = 0, limit: int = 100, 
    db: Session = Depends(get_db),
    current_admin: models.User = Depends(dependencies.get_current_active_admin)
):
    users = db.query(models.User).offset(skip).limit(limit).all()
    return users

@router.get("/{user_id}", response_model=schemas.UserResponse)
def read_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_admin: models.User = Depends(dependencies.get_current_active_admin)
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.post("/", response_model=schemas.UserResponse)
def create_user(
    user_in: schemas.UserCreate, 
    db: Session = Depends(get_db),
    current_admin: models.User = Depends(dependencies.get_current_active_admin)
):
    if len(user_in.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    existing_user = db.query(models.User).filter(models.User.email == user_in.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="User with this email already exists")
    
    try:
        res = supabase_admin.auth.admin.create_user({
            "email": user_in.email,
            "password": user_in.password,
            "email_confirm": True
        })
        supabase_user_id = res.user.id
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to create user in auth provider: {str(e)}")
        
    new_user = models.User(
        id=supabase_user_id,
        name=user_in.name,
        email=user_in.email,
        role=user_in.role if user_in.role else "USER",
        is_active=True
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@router.patch("/{user_id}", response_model=schemas.UserResponse)
def update_user(
    user_id: str,
    user_in: schemas.UserUpdate,
    db: Session = Depends(get_db),
    current_admin: models.User = Depends(dependencies.get_current_active_admin)
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Prevent admin from deactivating themselves or demoting themselves
    if current_admin.id == user_id:
        if user_in.is_active is False:
            raise HTTPException(status_code=400, detail="Cannot deactivate yourself")
        if user_in.role is not None and user_in.role != "ADMIN":
            raise HTTPException(status_code=400, detail="Cannot remove your own ADMIN privileges")
            
    # Prevent deactivating or demoting the last active ADMIN
    if user.role == "ADMIN" and user.is_active:
        if user_in.is_active is False or (user_in.role is not None and user_in.role != "ADMIN"):
            active_admins = db.query(models.User).filter(
                models.User.role == "ADMIN", 
                models.User.is_active == True
            ).count()
            if active_admins <= 1:
                raise HTTPException(status_code=400, detail="Cannot deactivate or demote the last active ADMIN")

    if user_in.name is not None:
        user.name = user_in.name
    if user_in.role is not None:
        user.role = user_in.role
    if user_in.is_active is not None:
        user.is_active = user_in.is_active
        
    db.commit()
    db.refresh(user)
    return user

@router.delete("/{user_id}", response_model=schemas.UserResponse)
def deactivate_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_admin: models.User = Depends(dependencies.get_current_active_admin)
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    if current_admin.id == user_id:
        raise HTTPException(status_code=400, detail="Cannot deactivate yourself")
        
    if user.role == "ADMIN" and user.is_active:
        active_admins = db.query(models.User).filter(
            models.User.role == "ADMIN", 
            models.User.is_active == True
        ).count()
        if active_admins <= 1:
            raise HTTPException(status_code=400, detail="Cannot deactivate the last active ADMIN")

    user.is_active = False
    db.commit()
    db.refresh(user)
    return user
