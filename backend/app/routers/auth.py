from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from .. import schemas, models, dependencies
from ..dependencies import supabase_client, get_db
import logging

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

@router.post("/login")
def login(request: schemas.LoginRequest, db: Session = Depends(get_db)):
    try:
        response = supabase_client.auth.sign_in_with_password({
            "email": request.email,
            "password": request.password
        })
        if not response or not response.session:
            raise HTTPException(status_code=401, detail="Invalid credentials")
            
        user = db.query(models.User).filter(models.User.id == response.user.id).first()
        if not user or not user.is_active:
            raise HTTPException(status_code=401, detail="Account is inactive or not found")
            
        return {
            "access_token": response.session.access_token,
            "token_type": "bearer",
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "role": user.role,
                "is_active": user.is_active
            }
        }
    except Exception as e:
        logging.error(f"Login error: {str(e)}")
        raise HTTPException(status_code=401, detail="Invalid credentials")

@router.post("/logout")
def logout(current_user: models.User = Depends(dependencies.get_current_user)):
    return {"message": "Logged out successfully"}

@router.get("/me", response_model=schemas.UserResponse)
def read_users_me(current_user: models.User = Depends(dependencies.get_current_user)):
    return current_user
