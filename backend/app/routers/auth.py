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
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Login error: {str(e)}")
        err_str = str(e).lower()
        if "network" in err_str or "connection" in err_str or "socket" in err_str or "timeout" in err_str or "dns" in err_str:
            raise HTTPException(status_code=503, detail="Network Connectivity Error: Unable to connect to authentication server. Please check Wi-Fi/Internet connection.")
        if "invalid" in err_str or "credentials" in err_str or "grant" in err_str:
            raise HTTPException(status_code=401, detail="Invalid email or password. Please check your login credentials.")
        raise HTTPException(status_code=401, detail="Authentication failed. Please verify your email and password.")

@router.post("/logout")
def logout(current_user: models.User = Depends(dependencies.get_current_user)):
    return {"message": "Logged out successfully"}

@router.get("/me", response_model=schemas.UserResponse)
def read_users_me(current_user: models.User = Depends(dependencies.get_current_user)):
    return current_user
