from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from supabase import create_client, Client
from .database import SessionLocal
from .config import settings
from . import models

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/v1/auth/login")

anon_key = settings.supabase_publishable_key if settings.supabase_publishable_key else "dummy_key"
admin_key = settings.supabase_secret_key if settings.supabase_secret_key else anon_key

supabase_admin: Client = create_client(
    settings.supabase_url, 
    admin_key
)

supabase_client: Client = create_client(
    settings.supabase_url, 
    anon_key
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        user_response = supabase_client.auth.get_user(token)
        if not user_response or not user_response.user:
            raise HTTPException(status_code=401, detail="Invalid token")
        
        supabase_user = user_response.user
        
        user = db.query(models.User).filter(models.User.id == supabase_user.id).first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found in our database")
        
        if not user.is_active:
            raise HTTPException(status_code=403, detail="User is inactive")
            
        return user
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_current_active_admin(current_user: models.User = Depends(get_current_user)):
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Not enough privileges")
    return current_user
